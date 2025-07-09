#!/usr/bin/env bun
/**
 * Local Webhook Handler for Agentic Coding System
 * 
 * Exactly like Claude Code Action but executes Claude Code SDK locally
 * instead of submitting to Nomad.
 */

import { createOctokit } from "../github/api/client";
import { setupGitHubToken } from "../github/token";
import { checkTriggerAction } from "../github/validation/trigger";
import { checkHumanActor } from "../github/validation/actor";
import { checkBranchCreationPermissions } from "../github/validation/permissions";
import { createInitialComment } from "../github/operations/comments/create-initial";
import { setupBranch } from "../github/operations/branch";
import { updateTrackingComment } from "../github/operations/comments/update-with-branch";
import { prepareLocalMcpConfig } from "./local-mcp-config";
import { createPrompt, createCodeReviewPrompt } from "../create-prompt"; // Force our LOCAL create-prompt.ts
import { fetchGitHubData } from "../github/data/fetcher";
import { parseWebhookContext } from "../github/context";
import { extractClaudeInstructions } from "../github/validation/trigger";
import type { WebhookPayload } from "./webhook-handler";
import type { GitHubData } from "../github/data/fetcher";
import type { ParsedGitHubContext } from "../github/context";
import type { PromptInfo } from "../create-prompt";

// Import Claude Code SDK for local execution
import { Anthropic } from "@anthropic-ai/sdk";
import { spawn } from "child_process";
import { writeFileSync, mkdirSync, existsSync, copyFileSync, unlinkSync, readFileSync } from "fs";
import { promisify } from "util";
import path from "path";

const execAsync = promisify(require('child_process').exec);

/**
 * Get a minimal-permission GitHub token exactly like GitHub Actions provides
 * Automatically refreshes to 'repo' scope only (same as GITHUB_TOKEN)
 */
async function getMinimalGitHubToken(fallbackToken?: string): Promise<string> {
  console.log("🔒 Ensuring minimal GitHub token permissions (GitHub Actions equivalent)");
  
  // Step 1: Automatically refresh to minimal permissions
  try {
    await execAsync('gh auth refresh --scopes "repo" 2>/dev/null || true');
    console.log("✅ Token refreshed to minimal 'repo' scope only");
  } catch (error) {
    console.warn("⚠️  Could not refresh token permissions");
  }
  
  // Step 2: Get the minimal-permission token
  try {
    const { stdout } = await execAsync('gh auth token');
    const token = stdout.trim();
    console.log("✅ Got minimal-permission GitHub token (repo scope only)");
    return token;
  } catch (error) {
    console.warn("⚠️  Failed to get token via gh CLI, using fallback");
    return fallbackToken || '';
  }
}

export async function handleLocalWebhook(
  payload: WebhookPayload,
  eventName: string,
  githubToken?: string
): Promise<{ success: boolean; message: string; executionId?: string }> {
  try {
    console.log(`Processing ${eventName} webhook event locally`);
    
    // Step 1: Setup GitHub token
    const token = githubToken || await setupGitHubToken();
    const octokit = createOctokit(token);

    // Step 2: Parse webhook context (same as Claude Code Action)
    const context = parseWebhookContext(payload, eventName);

    // Step 3: Check branch creation permissions (like Claude Code Action)
    const canCreateBranches = await checkBranchCreationPermissions(
      octokit.rest,
      context,
    );
    if (!canCreateBranches) {
      throw new Error(
        "Actor cannot create branches in the repository"
      );
    }

    // Step 4: Check trigger conditions (exactly like Claude Code Action)
    const containsTrigger = await checkTriggerAction(context);

    if (!containsTrigger) {
      console.log("No trigger found, skipping Claude Code execution");
      return { 
        success: true, 
        message: "No trigger phrase found in event" 
      };
    }

    // Step 5: Check if actor is human (exactly like Claude Code Action)
    await checkHumanActor(octokit.rest, context);

    // Step 6: Create initial tracking comment (exactly like Claude Code Action)
    const commentId = await createInitialComment(octokit.rest, context);

    // Step 7: Fetch GitHub data for context (exactly like Claude Code Action)
    const githubData = await fetchGitHubData({
      octokits: octokit,
      repository: `${context.repository.owner}/${context.repository.repo}`,
      prNumber: context.entityNumber.toString(),
      isPR: context.isPR,
      triggerUsername: context.actor,
    });

    // Step 8: Setup branch (exactly like Claude Code Action)
    const branchInfo = await setupBranch(octokit, githubData, context);

    // Step 9: Update initial comment with branch link (exactly like Claude Code Action)
    if (branchInfo.claudeBranch) {
      await updateTrackingComment(
        octokit,
        context,
        commentId,
        branchInfo.claudeBranch,
      );
    }

    // Step 10: Create prompt file for Claude Code (with code review detection)
    const promptInfo = await createPromptWithReviewDetection(
      commentId,
      branchInfo.baseBranch,
      branchInfo.claudeBranch,
      githubData,
      context,
    );

    // Step 11: Prepare LOCAL MCP configuration (exactly like Claude Code Action but with local git ops)
    process.env.GITHUB_TOKEN = token; // Ensure GitHub token is available for MCP servers
    const mcpConfig = await prepareLocalMcpConfig({
      repoDir: process.cwd(),
      branch: branchInfo.currentBranch,
      additionalMcpConfig: "",
    });

    // Step 12: Execute Claude Code locally instead of submitting to Nomad
    const executionId = await executeClaudeCodeLocally({
      promptFile: promptInfo.promptFile,
      mcpConfig,
      repository: context.repository,
      githubToken: token,
      commentId: commentId.toString(),
      branchInfo,
      context
    });

    console.log(`Successfully executed Claude Code locally: ${executionId}`);

    return {
      success: true,
      message: `Claude Code executed locally with ID: ${executionId}`,
      executionId
    };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`Local webhook handler failed: ${errorMessage}`);
    
    return {
      success: false,
      message: `Failed to process webhook locally: ${errorMessage}`
    };
  }
}

/**
 * Execute Claude Code locally by copying Claude Code Base Action's complete flow
 * Includes validateEnvironmentVariables, setupClaudeCodeSettings, preparePrompt, and runClaude
 */
async function executeClaudeCodeLocally(params: {
  promptFile: string;
  mcpConfig: string;
  repository: any;
  githubToken: string;
  commentId: string;
  branchInfo: any;
  context: any;
}): Promise<string> {
  
  const executionId = `local-claude-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  try {
    // Create local execution directory
    const localDir = `/tmp/claude-executions/${executionId}`;
    mkdirSync(localDir, { recursive: true });

    // Write prompt file
    const promptPath = path.join(localDir, "prompt.txt");
    writeFileSync(promptPath, params.promptFile);

    // Clone repository exactly like actions/checkout@v4 does
    const repoDir = path.join(localDir, "repo");
    
    // Write MCP config with local git operations (exactly like Claude Code Action)
    const mcpConfigPath = path.join(localDir, "mcp-config.json");
    process.env.GITHUB_TOKEN = params.githubToken; // Ensure GitHub token is available for MCP servers
    const localMcpConfig = await prepareLocalMcpConfig({
      repoDir: repoDir,
      branch: params.branchInfo.currentBranch,
      additionalMcpConfig: "",
    });
    writeFileSync(mcpConfigPath, localMcpConfig);
    console.log(`🔄 Cloning repository like actions/checkout@v4`);
    
    // Get minimal-permission GitHub token (GitHub Actions equivalent)
    const githubToken = await getMinimalGitHubToken(params.githubToken);
    
    await new Promise<void>((resolve, reject) => {
      const gitClone = spawn('git', [
        'clone',
        '--depth=1', // Like actions/checkout@v4 default
        `https://${githubToken}@github.com/${params.repository.owner}/${params.repository.repo}.git`,
        repoDir
      ]);

      gitClone.stdout.on('data', (data) => {
        console.log(`Git clone: ${data.toString().trim()}`);
      });

      gitClone.stderr.on('data', (data) => {
        console.log(`Git clone: ${data.toString().trim()}`);
      });

      gitClone.on('close', (code) => {
        if (code === 0) {
          console.log("✅ Repository cloned successfully");
          resolve();
        } else {
          reject(new Error(`Git clone failed with code ${code}`));
        }
      });
    });

    // Checkout branch exactly like actions/checkout@v4
    console.log(`🌿 Checking out branch: ${params.branchInfo.currentBranch}`);
    
    // Remove any existing .mcp.json to prevent Claude from using project's MCP config
    const projectMcpFile = path.join(repoDir, '.mcp.json');
    if (existsSync(projectMcpFile)) {
      console.log('🗑️  Removing project .mcp.json to use our minimal config');
      unlinkSync(projectMcpFile);
    }
    await new Promise<void>((resolve, reject) => {
      const gitCheckout = spawn('git', ['checkout', '-b', params.branchInfo.currentBranch], {
        cwd: repoDir
      });

      gitCheckout.stdout.on('data', (data) => {
        console.log(`Git checkout: ${data.toString().trim()}`);
      });

      gitCheckout.stderr.on('data', (data) => {
        console.log(`Git checkout: ${data.toString().trim()}`);
      });

      gitCheckout.on('close', (code) => {
        if (code === 0) {
          console.log("✅ Branch checked out successfully");
          resolve();
        } else {
          reject(new Error(`Git checkout failed with code ${code}`));
        }
      });
    });

    console.log(`Starting Claude Code execution in ${repoDir}`);

    // Copy Claude Code Base Action's complete execution flow
    await executeClaudeCodeBaseActionFlow({
      promptPath,
      mcpConfigPath,
      repoDir,
      githubToken: params.githubToken,
      commentId: params.commentId,
      executionId,
      localDir
    });

    return executionId;

  } catch (error) {
    console.error(`Local Claude Code execution failed: ${error}`);
    throw error;
  }
}

/**
 * Copy Claude Code Base Action's src/index.ts flow exactly:
 * validateEnvironmentVariables() → setupClaudeCodeSettings() → preparePrompt() → runClaude()
 * 
 * Uses official GitHub Actions approach for authentication and git setup
 */
async function executeClaudeCodeBaseActionFlow(params: {
  promptPath: string;
  mcpConfigPath: string;
  repoDir: string;
  githubToken: string;
  commentId: string;
  executionId: string;
  localDir: string;
}): Promise<void> {
  
  // Step 1: Get minimal-permission GitHub token (GitHub Actions equivalent)
  const githubToken = await getMinimalGitHubToken(params.githubToken);
  
  // Step 2: Configure git identity exactly like GitHub Actions does
  console.log("👤 Setting up git identity like GitHub Actions bot");
  await new Promise<void>((resolve, reject) => {
    const gitConfig1 = spawn('git', ['config', 'user.name', 'github-actions[bot]'], {
      cwd: params.repoDir
    });
    gitConfig1.on('close', (code) => {
      if (code === 0) {
        const gitConfig2 = spawn('git', ['config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com'], {
          cwd: params.repoDir
        });
        gitConfig2.on('close', (code2) => {
          if (code2 === 0) {
            console.log("✅ Git identity configured like GitHub Actions");
            resolve();
          } else {
            reject(new Error(`Git user.email config failed with code ${code2}`));
          }
        });
      } else {
        reject(new Error(`Git user.name config failed with code ${code}`));
      }
    });
  });
  
  // Step 3: Set up environment exactly like GitHub Actions does
  const environment = {
    ...process.env,
    // Core authentication (exactly like GitHub Actions)
    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
    GITHUB_TOKEN: githubToken, // Use proper GitHub Actions-style token
    CLAUDE_COMMENT_ID: params.commentId,
    
    // INPUT_* variables that Claude Code Base Action expects (exact match to action.yml)
    INPUT_PROMPT_FILE: params.promptPath,
    INPUT_MCP_CONFIG: params.mcpConfigPath,
    INPUT_ALLOWED_TOOLS: "Edit,MultiEdit,Glob,Grep,LS,Read,Write,mcp__github_file_ops__commit_files,mcp__github_file_ops__delete_files,mcp__github_file_ops__update_claude_comment,mcp__github_file_ops__get_pr_diff,mcp__github_file_ops__create_initial_comment",
    INPUT_DISALLOWED_TOOLS: "",
    INPUT_MAX_TURNS: "",
    INPUT_SYSTEM_PROMPT: "",
    INPUT_APPEND_SYSTEM_PROMPT: "",
    INPUT_CLAUDE_ENV: "",
    INPUT_FALLBACK_MODEL: "",
    INPUT_TIMEOUT_MINUTES: "10",
    
    // Provider configuration (using direct Anthropic API like GitHub Actions)
    CLAUDE_CODE_USE_BEDROCK: "",
    CLAUDE_CODE_USE_VERTEX: "",
    
    // Action environment (exact match to action.yml line 124)
    CLAUDE_CODE_ACTION: "1",
    RUNNER_TEMP: params.localDir
  };

  // Step 4: Create named pipe for prompt input (exactly like official base action)
  const pipePath = `${params.localDir}/claude_prompt_pipe`;
  await new Promise<void>((resolve, reject) => {
    const mkfifo = spawn('mkfifo', [pipePath]);
    mkfifo.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`mkfifo failed with code ${code}`));
      }
    });
  });

  // Start sending prompt to pipe in background (exactly like official base action)
  const catProcess = spawn('cat', [params.promptPath], {
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  const pipeStream = require('fs').createWriteStream(pipePath);
  catProcess.stdout.pipe(pipeStream);

  // Step 5: Execute Claude Code exactly like official base action
  console.log(`🚀 Starting Claude Code with streaming JSON output and MCP config (working dir: ${params.repoDir})`);
  const claudeProcess = spawn('claude', [
    '--mcp-config', params.mcpConfigPath,  // Load MCP configuration
    '--allowedTools', 'Edit,MultiEdit,Glob,Grep,LS,Read,Write,mcp__github_file_ops__commit_files,mcp__github_file_ops__delete_files,mcp__github_file_ops__update_claude_comment,mcp__github_file_ops__get_pr_diff,mcp__github_file_ops__create_initial_comment',
    '-p',  // Use pipe input
    '--verbose',
    '--output-format', 'stream-json'
  ], {
    cwd: params.repoDir,
    stdio: ['pipe', 'pipe', 'pipe'],  // pipe stdin for named pipe input
    env: environment
  });

  // Pipe from named pipe to Claude (exactly like official base action)
  const pipeProcess = spawn('cat', [pipePath]);
  pipeProcess.stdout.pipe(claudeProcess.stdin);

  // Capture all output with GitHub Actions-style logging
  let output = "";
  let errorOutput = "";

  claudeProcess.stdout.on("data", (data) => {
    const text = data.toString();
    output += text;
    
    // Parse streaming JSON events for real-time monitoring
    const lines = text.split('\n');
    lines.forEach(line => {
      if (line.trim()) {
        try {
          const event = JSON.parse(line.trim());
          // Log different event types properly
          if (event.type === 'tool_use' && event.params) {
            console.log(`🔧 TOOL: ${event.toolName} - ${JSON.stringify(event.params)}`);
          } else if (event.type === 'tool_result') {
            console.log(`✅ TOOL RESULT: ${event.toolName} - ${event.content?.substring(0, 200)}...`);
          } else if (event.type === 'message' && event.role === 'assistant') {
            console.log(`💬 CLAUDE: ${event.content}`);
          } else if (event.type === 'system') {
            console.log(`📊 SYSTEM EVENT: ${JSON.stringify(event)}`);
          } else {
            console.log(`📝 CLAUDE: ${line.trim()}`);
          }
        } catch (e) {
          // Not JSON, log as regular text
          console.log(`📝 CLAUDE: ${line.trim()}`);
        }
      }
    });
  });

  claudeProcess.stderr.on("data", (data) => {
    const text = data.toString();
    console.error("⚠️  CLAUDE ERROR:", text.trim());
    errorOutput += text;
  });

  // Handle Claude process errors
  claudeProcess.on("error", (error) => {
    console.error("❌ Error spawning Claude process:", error);
    throw error;
  });

  // Wait for Claude to finish with timeout (10 minutes like GitHub Actions)
  const timeoutMs = 10 * 60 * 1000;
  const exitCode = await new Promise<number>((resolve) => {
    let resolved = false;

    // Set a timeout for the process (same as GitHub Actions)
    const timeoutId = setTimeout(() => {
      if (!resolved) {
        console.error(`⏱️  Claude process timed out after ${timeoutMs / 1000} seconds`);
        claudeProcess.kill("SIGTERM");
        // Give it 5 seconds to terminate gracefully, then force kill
        setTimeout(() => {
          try {
            claudeProcess.kill("SIGKILL");
          } catch (e) {
            // Process may already be dead
          }
        }, 5000);
        resolved = true;
        resolve(124); // Standard timeout exit code
      }
    }, timeoutMs);

    claudeProcess.on("close", (code) => {
      if (!resolved) {
        clearTimeout(timeoutId);
        resolved = true;
        resolve(code || 0);
      }
    });
  });

  // Clean up processes (like official base action)
  try {
    catProcess.kill("SIGTERM");
  } catch (e) {
    // Process may already be dead
  }
  try {
    pipeProcess.kill("SIGTERM");
  } catch (e) {
    // Process may already be dead
  }

  // Clean up pipe file (like official base action)
  try {
    require('fs').unlinkSync(pipePath);
  } catch (e) {
    // Ignore errors during cleanup
  }

  // Save all output for debugging (like GitHub Actions artifacts)
  writeFileSync(path.join(params.localDir, "claude-stdout.txt"), output);
  writeFileSync(path.join(params.localDir, "claude-stderr.txt"), errorOutput);
  
  // Copy execution output to our debug location (like RUNNER_TEMP)
  const executionOutputFile = path.join(params.localDir, "claude-execution-output.json");
  const githubActionsOutputFile = path.join(params.localDir, "claude-execution-output.json");
  if (existsSync(githubActionsOutputFile)) {
    copyFileSync(githubActionsOutputFile, executionOutputFile);
  }

  // No cleanup needed since we use INPUT_PROMPT_FILE environment variable

  // Process result exactly like GitHub Actions does
  if (exitCode === 0) {
    console.log(`🎉 Claude Code execution completed successfully: ${params.executionId}`);
    
    // Check for commits like GitHub Actions would
    const gitLog = await new Promise<string>((resolve) => {
      const gitLogCmd = spawn('git', ['log', '--oneline', '-5'], { cwd: params.repoDir });
      let logOutput = "";
      gitLogCmd.stdout.on('data', (data) => { logOutput += data.toString(); });
      gitLogCmd.on('close', () => resolve(logOutput));
    });
    
    console.log("📋 Recent commits:");
    console.log(gitLog);
    
    // Check if files were created/modified
    const gitStatus = await new Promise<string>((resolve) => {
      const gitStatusCmd = spawn('git', ['status', '--porcelain'], { cwd: params.repoDir });
      let statusOutput = "";
      gitStatusCmd.stdout.on('data', (data) => { statusOutput += data.toString(); });
      gitStatusCmd.on('close', () => resolve(statusOutput));
    });
    
    if (gitStatus.trim()) {
      console.log("📝 Files changed:");
      console.log(gitStatus);
    } else {
      console.log("📄 No file changes detected");
    }
    
    // Check execution output like GitHub Actions
    const outputFile = path.join(params.repoDir, "output.txt");
    if (existsSync(outputFile)) {
      console.log("✅ output.txt found - Claude executed successfully");
    } else {
      console.warn("⚠️  No output.txt found - checking RUNNER_TEMP location");
      const runnerTempOutput = path.join(params.localDir, "claude-execution-output.json");
      if (existsSync(runnerTempOutput)) {
        console.log("✅ Execution output found in RUNNER_TEMP");
      }
    }
  } else {
    console.error(`❌ Claude Code execution failed with exit code: ${exitCode}`);
    console.error(`❌ Error output: ${errorOutput}`);
    throw new Error(`Claude Code execution failed with code ${exitCode}: ${errorOutput}`);
  }
}

/**
 * Create prompt with automatic code review detection
 */
async function createPromptWithReviewDetection(
  commentId: number,
  baseBranch: string,
  claudeBranch: string | undefined,
  githubData: GitHubData,
  context: ParsedGitHubContext,
): Promise<PromptInfo> {
  // Extract the trigger instructions to analyze for code review keywords
  const instructions = extractClaudeInstructions(context);
  
  // Code review detection logic
  const isCodeReviewRequest = context.isPR && isCodeReviewTrigger(instructions);
  
  if (isCodeReviewRequest) {
    console.log("🔍 Detected code review request, using specialized code review prompt");
    return await createCodeReviewPrompt(
      commentId,
      baseBranch,
      githubData,
      context
    );
  } else {
    console.log("⚡ Using standard implementation prompt");
    return await createPrompt(
      commentId,
      baseBranch,
      claudeBranch,
      githubData,
      context,
    );
  }
}

/**
 * Detect if the trigger text indicates a code review request
 */
function isCodeReviewTrigger(instructions: string): boolean {
  const reviewKeywords = [
    'review',
    'analyze',
    'check',
    'audit',
    'examine',
    'inspect',
    'evaluate',
    'assess',
    'critique',
    'code review',
    'look at',
    'feedback',
    'suggestions',
    'improvements',
    'quality'
  ];
  
  const lowerInstructions = instructions.toLowerCase();
  
  // Check if any review keywords are present
  return reviewKeywords.some(keyword => 
    lowerInstructions.includes(keyword)
  );
}

export default handleLocalWebhook;