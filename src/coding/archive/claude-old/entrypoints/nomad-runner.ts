#!/usr/bin/env bun
/**
 * Nomad Job Runner for Agentic Coding System
 * 
 * Submits Claude Code execution jobs to our Nomad cluster.
 * Replaces GitHub Actions runner from claude-code-action.
 * 
 * Related to GitHub Issue #15: Implement Agentic Coding System with Claude Code SDK Python Runtime
 */

import type { ParsedGitHubContext } from "../github/context";

export interface BranchInfo {
  baseBranch: string;
  claudeBranch?: string;
  currentBranch: string;
}

export interface NomadJobParams {
  promptFile: string;
  mcpConfig: string;
  repository: {
    owner: string;
    repo: string;
    clone_url?: string;
  };
  githubToken: string;
  commentId: string;
  branchInfo: BranchInfo;
  context: ParsedGitHubContext;
}

export async function submitNomadJob(params: NomadJobParams): Promise<string> {
  const {
    promptFile,
    mcpConfig,
    repository,
    githubToken,
    commentId,
    branchInfo,
    context
  } = params;

  // Generate unique job ID
  const jobId = `claude-code-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  console.log(`Submitting Nomad job: ${jobId}`);

  // Create Nomad job specification
  const nomadJob = {
    Job: {
      ID: jobId,
      Name: jobId,
      Type: "batch",
      Priority: 50,
      Datacenters: ["dc1"],
      TaskGroups: [{
        Name: "claude-code-runner",
        Count: 1,
        Tasks: [{
          Name: "claude-code",
          Driver: "docker",
          Config: {
            image: "oven/bun:1-alpine", // Use Alpine for smaller footprint
            memory_hard_limit: 7168, // Match Resources.MemoryMB
            command: "sh",
            args: ["-c", `
              set -ex  # Enable verbose mode
              
              echo "=== Starting Claude Code execution ==="
              echo "Container started at: $(date)"
              echo "Task directory: $(pwd)"
              
              # Install git and nodejs (for npm)
              echo "Installing git and nodejs..."
              apk add --no-cache git nodejs npm
              
              # Setup workspace
              echo "Setting up workspace..."
              mkdir -p /workspace
              cd /workspace
              
              # Debug: Check environment variables (but not secrets)
              echo "=== Environment Check ==="
              echo "ANTHROPIC_API_KEY is: $(if [ -n "$ANTHROPIC_API_KEY" ]; then echo 'SET'; else echo 'NOT SET'; fi)"
              echo "GITHUB_TOKEN is: $(if [ -n "$GITHUB_TOKEN" ]; then echo 'SET'; else echo 'NOT SET'; fi)"
              echo "CLAUDE_JOB_ID: $CLAUDE_JOB_ID"
              echo "REPOSITORY_OWNER: $REPOSITORY_OWNER"
              echo "REPOSITORY_NAME: $REPOSITORY_NAME"
              
              # Clone repository with GitHub token authentication
              echo "Cloning repository..."
              git clone https://$GITHUB_TOKEN@github.com/${repository.owner}/${repository.repo}.git repo
              cd repo
              
              # Checkout appropriate branch
              echo "Checking out branch: ${branchInfo.currentBranch}"
              git checkout ${branchInfo.currentBranch}
              
              # Check if prompt and config files exist in Nomad's local directory
              echo "=== Checking templated files ==="
              TASK_DIR=/local
              ls -la $TASK_DIR/prompt.txt || echo "prompt.txt not found in $TASK_DIR!"
              ls -la $TASK_DIR/mcp-config.json || echo "mcp-config.json not found in $TASK_DIR!"
              
              # Show first few lines of each file
              if [ -f $TASK_DIR/prompt.txt ]; then
                echo "=== First 5 lines of prompt.txt ==="
                head -5 $TASK_DIR/prompt.txt
              fi
              
              if [ -f $TASK_DIR/mcp-config.json ]; then
                echo "=== mcp-config.json content ==="
                cat $TASK_DIR/mcp-config.json
              fi
              
              # Create claude-runner.ts inline since it doesn't exist in the target repo
              echo "=== Creating claude-runner.ts ==="
              cat > /workspace/claude-runner.ts << 'CLAUDE_RUNNER_EOF'
#!/usr/bin/env bun
import fs from "fs/promises";
import { spawn } from "child_process";

async function main() {
  try {
    console.log("🚀 Starting Claude Code execution with CLI...");

    // Read configuration files from Nomad's local directory
    // Nomad templates store files as base64-encoded content
    const promptFileBase64 = await fs.readFile("/local/prompt.txt", "utf-8");
    const mcpConfigBase64 = await fs.readFile("/local/mcp-config.json", "utf-8");
    
    // Decode from base64
    console.log("📦 Decoding base64 content...");
    const promptFile = Buffer.from(promptFileBase64, 'base64').toString('utf-8');
    const mcpConfigRaw = Buffer.from(mcpConfigBase64, 'base64').toString('utf-8');
    const mcpConfig = JSON.parse(mcpConfigRaw);

    console.log("📋 Loaded prompt and MCP configuration");

    // Write decoded files to workspace for Claude CLI
    await fs.writeFile("/workspace/prompt.txt", promptFile);
    await fs.writeFile("/workspace/mcp-config.json", mcpConfigRaw);

    // Get environment variables
    const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
    const githubToken = process.env.GITHUB_TOKEN;
    const jobId = process.env.CLAUDE_JOB_ID;
    const commentId = process.env.CLAUDE_COMMENT_ID;

    if (!anthropicApiKey) {
      throw new Error("ANTHROPIC_API_KEY environment variable is required");
    }

    if (!githubToken) {
      throw new Error("GITHUB_TOKEN environment variable is required");
    }

    console.log("🎯 Job ID: " + jobId);
    console.log("💬 Comment ID: " + commentId);

    // Execute Claude using official CLI with MCP configuration
    console.log("🤖 Executing Claude with official CLI and MCP servers...");
    
    await executeClaudeWithCLI("/workspace/prompt.txt", "/workspace/mcp-config.json", {
      ANTHROPIC_API_KEY: anthropicApiKey,
      GITHUB_TOKEN: githubToken,
      CLAUDE_JOB_ID: jobId || "",
      CLAUDE_COMMENT_ID: commentId || ""
    });

    console.log("🎉 Claude execution completed successfully");

  } catch (error) {
    console.error("💥 Claude runner failed:", error);
    process.exit(1);
  }
}

/**
 * Execute Claude using the official Claude Code CLI with MCP configuration
 */
function executeClaudeWithCLI(promptPath, mcpConfigPath, env) {
  return new Promise((resolve, reject) => {
    console.log("🚀 Starting Claude Code CLI with MCP configuration...");
    
    const claudeProcess = spawn('claude', [
      '--mcp-config', mcpConfigPath,
      '--allowedTools', 'Edit,MultiEdit,Glob,Grep,LS,Read,Write,mcp__github_file_ops__commit_files,mcp__github_file_ops__delete_files,mcp__github_file_ops__update_claude_comment',
      '--verbose',
      promptPath
    ], {
      stdio: ['inherit', 'pipe', 'pipe'],
      env: {
        ...process.env,
        ...env
      }
    });

    let output = "";
    let errorOutput = "";

    claudeProcess.stdout.on('data', (data) => {
      const text = data.toString();
      output += text;
      console.log(text);
    });

    claudeProcess.stderr.on('data', (data) => {
      const text = data.toString();
      errorOutput += text;
      console.error(text);
    });

    claudeProcess.on('close', (code) => {
      if (code === 0) {
        console.log("✅ Claude Code CLI completed successfully");
        resolve();
      } else {
        console.error(\`❌ Claude Code CLI failed with exit code \${code}\`);
        console.error("Error output:", errorOutput);
        reject(new Error(\`Claude Code CLI failed with exit code \${code}: \${errorOutput}\`));
      }
    });

    claudeProcess.on('error', (error) => {
      console.error("❌ Failed to start Claude Code CLI:", error);
      reject(error);
    });
  });
}

main();
CLAUDE_RUNNER_EOF
              
              # Install Claude Code CLI instead of Anthropic SDK
              echo "Installing Claude Code CLI..."
              npm install -g @anthropic-ai/claude-code
              
              # Run our claude-runner.ts
              echo "=== Running claude-runner.ts ==="
              bun run /workspace/claude-runner.ts || {
                EXIT_CODE=$?
                echo "claude-runner.ts exited with code: $EXIT_CODE"
                exit $EXIT_CODE
              }
              
              echo "=== Claude Code execution completed successfully ==="
            `]
          },
          Env: {
            // Claude Code configuration
            ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || "",
            GITHUB_TOKEN: githubToken,
            
            // Job metadata
            CLAUDE_JOB_ID: jobId,
            CLAUDE_COMMENT_ID: commentId,
            REPOSITORY_OWNER: repository.owner,
            REPOSITORY_NAME: repository.repo,
            BASE_BRANCH: branchInfo.baseBranch,
            CLAUDE_BRANCH: branchInfo.claudeBranch || "",
            
            // GitHub context
            ISSUE_NUMBER: context.entityNumber?.toString() || "",
            IS_PR: context.isPR ? "true" : "false",
            TRIGGER_USER: context.actor,
            
            // Our infrastructure
            CLUSTER_NAME: process.env.CLUSTER_NAME || "local",
            NOMAD_ADDR: process.env.NOMAD_ADDR || "http://localhost:4646",
            TERRAGRUNT_CONFIG_PATH: "/infrastructure/terragrunt"
          },
          Resources: {
            CPU: 2000,      // 2 vCPU cores (2000 MHz)
            MemoryMB: 7168, // 7 GB RAM
            DiskMB: 14336   // 14 GB SSD storage
          },
          Templates: [
            {
              DestPath: "local/prompt.txt",
              EmbeddedTmpl: Buffer.from(promptFile).toString('base64'),
              ChangeMode: "noop"
            },
            {
              DestPath: "local/mcp-config.json", 
              EmbeddedTmpl: Buffer.from(mcpConfig).toString('base64'),
              ChangeMode: "noop"
            }
          ],
          LogConfig: {
            MaxFiles: 3,
            MaxFileSizeMB: 10
          }
        }]
      }]
    }
  };

  try {
    // Submit job to Nomad API
    const nomadEndpoint = process.env.NOMAD_ADDR || "http://localhost:4646";
    
    const response = await fetch(`${nomadEndpoint}/v1/jobs`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(nomadJob)
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Nomad API error: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    
    console.log(`Nomad job submitted successfully:`, {
      jobId,
      evalId: result.EvalID,
      evalIndex: result.EvalCreateIndex
    });

    return jobId;

  } catch (error) {
    console.error(`Failed to submit Nomad job: ${error}`);
    throw new Error(`Nomad job submission failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

export async function getNomadJobStatus(jobId: string): Promise<{
  status: string;
  summary?: any;
  allocations?: any[];
}> {
  try {
    const nomadEndpoint = process.env.NOMAD_ADDR || "http://localhost:4646";
    
    const response = await fetch(`${nomadEndpoint}/v1/job/${jobId}`);
    
    if (!response.ok) {
      throw new Error(`Nomad API error: ${response.status}`);
    }

    const job = await response.json();
    
    // Get allocations for this job
    const allocResponse = await fetch(`${nomadEndpoint}/v1/job/${jobId}/allocations`);
    const allocations = allocResponse.ok ? await allocResponse.json() : [];

    return {
      status: job.Status,
      summary: job.JobSummary,
      allocations
    };

  } catch (error) {
    console.error(`Failed to get Nomad job status: ${error}`);
    throw error;
  }
}

export async function getNomadJobLogs(jobId: string, taskName: string = "claude-code"): Promise<{
  stdout: string;
  stderr: string;
}> {
  try {
    const nomadEndpoint = process.env.NOMAD_ADDR || "http://localhost:4646";
    
    // Get allocations for job
    const allocResponse = await fetch(`${nomadEndpoint}/v1/job/${jobId}/allocations`);
    if (!allocResponse.ok) {
      throw new Error(`Failed to get allocations: ${allocResponse.status}`);
    }
    
    const allocations = await allocResponse.json();
    if (allocations.length === 0) {
      throw new Error("No allocations found for job");
    }

    const allocId = allocations[0].ID;
    
    // Get stdout
    const stdoutResponse = await fetch(`${nomadEndpoint}/v1/client/fs/logs/${allocId}?task=${taskName}&type=stdout&plain=true`);
    const stdout = stdoutResponse.ok ? await stdoutResponse.text() : "";
    
    // Get stderr  
    const stderrResponse = await fetch(`${nomadEndpoint}/v1/client/fs/logs/${allocId}?task=${taskName}&type=stderr&plain=true`);
    const stderr = stderrResponse.ok ? await stderrResponse.text() : "";

    return { stdout, stderr };

  } catch (error) {
    console.error(`Failed to get Nomad job logs: ${error}`);
    throw error;
  }
}