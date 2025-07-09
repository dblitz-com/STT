#!/usr/bin/env bun
/**
 * Claude Runner - Batch Job for Claude Code CLI execution
 * 
 * This runs as a batch job that reads prompt and MCP config from files
 * and executes Claude Code CLI once, then exits. Designed for Kubernetes Jobs.
 * 
 * Follows EXACTLY the same pattern as claude-code-base-action:
 * 1. Read prompt and MCP config files from Kubernetes volumes
 * 2. Create named pipe for prompt input (mkfifo)
 * 3. Execute Claude CLI with -p flag for pipe input
 * 4. Exit with appropriate code
 * 
 * Related to GitHub Issue #15: Implement Agentic Coding System
 */

import fs from "fs/promises";
import { spawn } from "child_process";
import { promisify } from "util";
import { createWriteStream } from "fs";
import path from "path";

const execAsync = promisify(require('child_process').exec);

interface McpServer {
  command: string;
  args?: string[];
  env?: Record<string, string>;
}

interface McpConfig {
  mcpServers: Record<string, McpServer>;
}

async function main() {
  try {
    console.log("🚀 Starting Claude Code execution with CLI (GitHub Actions compatible)...");

    // Set RUNNER_TEMP to /tmp if not set (GitHub Actions compatibility)
    if (!process.env.RUNNER_TEMP) {
      process.env.RUNNER_TEMP = "/tmp";
    }

    // Read configuration files from standard locations
    // These files are provided by Kubernetes ConfigMaps
    let promptFile: string;
    let mcpConfigRaw: string;
    let mcpConfig: McpConfig;

    // Read files from standard Kubernetes locations
    const promptPath = "/tmp/prompt.txt";
    const mcpConfigPath = "/tmp/mcp-config.json";

    try {
      console.log("📦 Reading prompt and MCP configuration files...");
      promptFile = await fs.readFile(promptPath, "utf-8");
      mcpConfigRaw = await fs.readFile(mcpConfigPath, "utf-8");
      
    } catch (error) {
      console.error("❌ Could not read prompt or MCP config files");
      console.error("Expected locations:");
      console.error("  - /tmp/prompt.txt");
      console.error("  - /tmp/mcp-config.json");
      console.error("These files should be provided by Kubernetes ConfigMaps or volumes");
      throw new Error(`Failed to read configuration files: ${error}`);
    }

    // Parse MCP configuration
    try {
      mcpConfig = JSON.parse(mcpConfigRaw);
    } catch (parseError) {
      console.error("❌ Failed to parse MCP configuration as JSON");
      throw new Error(`Invalid MCP configuration JSON: ${parseError}`);
    }

    console.log("📋 Loaded prompt and MCP configuration");
    console.log(`📊 MCP Servers: ${Object.keys(mcpConfig.mcpServers || {}).join(", ")}`);

    // Get environment variables
    const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
    const githubToken = process.env.GITHUB_TOKEN;
    const jobId = process.env.CLAUDE_JOB_ID;
    const commentId = process.env.CLAUDE_COMMENT_ID;
    const allowedTools = process.env.INPUT_ALLOWED_TOOLS || "Edit,MultiEdit,Glob,Grep,LS,Read,Write,mcp__github_file_ops__commit_files,mcp__github_file_ops__delete_files,mcp__github_file_ops__update_claude_comment,mcp__github_file_ops__get_pr_diff,mcp__github_file_ops__create_initial_comment";
    const disallowedTools = process.env.INPUT_DISALLOWED_TOOLS || "";
    const maxTurns = process.env.INPUT_MAX_TURNS || "";
    const systemPrompt = process.env.INPUT_SYSTEM_PROMPT || "";
    const appendSystemPrompt = process.env.INPUT_APPEND_SYSTEM_PROMPT || "";
    const timeoutMinutes = process.env.INPUT_TIMEOUT_MINUTES || "10";
    const fallbackModel = process.env.INPUT_FALLBACK_MODEL || "";

    if (!anthropicApiKey) {
      throw new Error("ANTHROPIC_API_KEY environment variable is required");
    }

    if (!githubToken) {
      throw new Error("GITHUB_TOKEN environment variable is required");
    }

    console.log("🎯 Job ID: " + (jobId || "unknown"));
    console.log("💬 Comment ID: " + (commentId || "unknown"));

    // Execute Claude using official CLI with MCP configuration
    console.log("🤖 Executing Claude with official CLI and MCP servers (GitHub Actions pattern)...");
    
    await executeClaudeWithCLI(promptPath, mcpConfigPath, {
      allowedTools,
      disallowedTools,
      maxTurns,
      systemPrompt,
      appendSystemPrompt,
      timeoutMinutes,
      fallbackModel,
      env: {
        ANTHROPIC_API_KEY: anthropicApiKey,
        GITHUB_TOKEN: githubToken,
        CLAUDE_JOB_ID: jobId || "",
        CLAUDE_COMMENT_ID: commentId || "",
        CLAUDE_CODE_ACTION: "1",
        RUNNER_TEMP: process.env.RUNNER_TEMP || "/tmp"
      }
    });

    console.log("🎉 Claude execution completed successfully");
    process.exit(0);

  } catch (error) {
    console.error("💥 Claude runner failed:", error);
    process.exit(1);
  }
}

interface ClaudeOptions {
  allowedTools: string;
  disallowedTools: string;
  maxTurns: string;
  systemPrompt: string;
  appendSystemPrompt: string;
  timeoutMinutes: string;
  fallbackModel: string;
  env: Record<string, string>;
}

/**
 * Execute Claude using the official Claude Code CLI with MCP configuration
 * Follows EXACTLY the same pattern as claude-code-base-action/src/run-claude.ts
 * Uses named pipes for prompt input, just like GitHub Actions
 */
async function executeClaudeWithCLI(
  promptPath: string, 
  mcpConfigPath: string, 
  options: ClaudeOptions
): Promise<void> {
  const PIPE_PATH = `${process.env.RUNNER_TEMP}/claude_prompt_pipe`;
  const EXECUTION_FILE = `${process.env.RUNNER_TEMP}/claude-execution-output.json`;
  const BASE_ARGS = ["-p", "--verbose", "--output-format", "stream-json"];

  // Create named pipe (exactly like official base action)
  try {
    await fs.unlink(PIPE_PATH);
  } catch (e) {
    // Ignore if file doesn't exist
  }

  // Create the named pipe
  await execAsync(`mkfifo "${PIPE_PATH}"`);

  // Log prompt file size
  let promptSize = "unknown";
  try {
    const stats = await fs.stat(promptPath);
    promptSize = stats.size.toString();
  } catch (e) {
    // Ignore error
  }
  console.log(`Prompt file size: ${promptSize} bytes`);

  // Build Claude arguments (exactly like official base action)
  const claudeArgs = [...BASE_ARGS];
  
  if (options.allowedTools) {
    claudeArgs.push("--allowedTools", options.allowedTools);
  }
  if (options.disallowedTools) {
    claudeArgs.push("--disallowedTools", options.disallowedTools);
  }
  if (options.maxTurns) {
    claudeArgs.push("--max-turns", options.maxTurns);
  }
  if (mcpConfigPath) {
    claudeArgs.push("--mcp-config", mcpConfigPath);
  }
  if (options.systemPrompt) {
    claudeArgs.push("--system-prompt", options.systemPrompt);
  }
  if (options.appendSystemPrompt) {
    claudeArgs.push("--append-system-prompt", options.appendSystemPrompt);
  }
  if (options.fallbackModel) {
    claudeArgs.push("--fallback-model", options.fallbackModel);
  }

  console.log(`Running Claude with prompt from file: ${promptPath}`);

  // Start sending prompt to pipe in background (exactly like official base action)
  const catProcess = spawn("cat", [promptPath], {
    stdio: ["ignore", "pipe", "inherit"],
  });
  const pipeStream = createWriteStream(PIPE_PATH);
  catProcess.stdout.pipe(pipeStream);

  catProcess.on("error", (error) => {
    console.error("Error reading prompt file:", error);
    pipeStream.destroy();
  });

  const claudeProcess = spawn('claude', claudeArgs, {
    stdio: ['pipe', 'pipe', 'inherit'],
    env: {
      ...process.env,
      ...options.env
    }
  });

  // Handle Claude process errors
  claudeProcess.on("error", (error) => {
    console.error("Error spawning Claude process:", error);
    pipeStream.destroy();
  });

  // Capture output for parsing execution metrics
  let output = "";
  claudeProcess.stdout.on("data", (data) => {
    const text = data.toString();
    
    // Try to parse as JSON and pretty print if it's on a single line (exactly like official base action)
    const lines = text.split("\n");
    lines.forEach((line: string, index: number) => {
      if (line.trim() === "") return;

      try {
        // Check if this line is a JSON object
        const parsed = JSON.parse(line);
        const prettyJson = JSON.stringify(parsed, null, 2);
        process.stdout.write(prettyJson);
        if (index < lines.length - 1 || text.endsWith("\n")) {
          process.stdout.write("\n");
        }
      } catch (e) {
        // Not a JSON object, print as is
        process.stdout.write(line);
        if (index < lines.length - 1 || text.endsWith("\n")) {
          process.stdout.write("\n");
        }
      }
    });

    output += text;
  });

  // Handle stdout errors
  claudeProcess.stdout.on("error", (error) => {
    console.error("Error reading Claude stdout:", error);
  });

  // Pipe from named pipe to Claude (exactly like official base action)
  const pipeProcess = spawn("cat", [PIPE_PATH]);
  pipeProcess.stdout.pipe(claudeProcess.stdin);

  // Handle pipe process errors
  pipeProcess.on("error", (error) => {
    console.error("Error reading from named pipe:", error);
    claudeProcess.kill("SIGTERM");
  });

  // Wait for Claude to finish with timeout (exactly like official base action)
  const timeoutMs = parseInt(options.timeoutMinutes, 10) * 60 * 1000;
  const exitCode = await new Promise<number>((resolve) => {
    let resolved = false;

    // Set a timeout for the process
    const timeoutId = setTimeout(() => {
      if (!resolved) {
        console.error(
          `Claude process timed out after ${timeoutMs / 1000} seconds`
        );
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

    claudeProcess.on("error", (error) => {
      if (!resolved) {
        console.error("Claude process error:", error);
        clearTimeout(timeoutId);
        resolved = true;
        resolve(1);
      }
    });
  });

  // Clean up processes
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

  // Clean up pipe file
  try {
    await fs.unlink(PIPE_PATH);
  } catch (e) {
    // Ignore errors during cleanup
  }

  // Set conclusion based on exit code (exactly like official base action)
  if (exitCode === 0) {
    // Try to process the output and save execution metrics
    try {
      await fs.writeFile("output.txt", output);

      // Process output.txt into JSON and save to execution file
      const { stdout: jsonOutput } = await execAsync("jq -s '.' output.txt");
      await fs.writeFile(EXECUTION_FILE, jsonOutput);

      console.log(`Log saved to ${EXECUTION_FILE}`);
    } catch (e) {
      console.warn(`Failed to process output for execution metrics: ${e}`);
    }

    console.log("✅ Claude Code execution completed successfully");
  } else {
    // Still try to save execution file if we have output
    if (output) {
      try {
        await fs.writeFile("output.txt", output);
        const { stdout: jsonOutput } = await execAsync("jq -s '.' output.txt");
        await fs.writeFile(EXECUTION_FILE, jsonOutput);
      } catch (e) {
        // Ignore errors when processing output during failure
      }
    }

    throw new Error(`Claude Code execution failed with exit code ${exitCode}`);
  }
}

// Run if called directly (batch job execution)
if (import.meta.main) {
  main();
}

export { main, executeClaudeWithCLI };