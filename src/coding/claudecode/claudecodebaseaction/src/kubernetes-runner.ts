#!/usr/bin/env bun
/**
 * Kubernetes Runner for Claude Code Base Action
 * 
 * Replaces GitHub Actions composite action with direct execution.
 * This is the low-level Claude CLI executor that runs in Kubernetes.
 */

import { preparePrompt } from "./prepare-prompt";
import { runClaude } from "./run-claude";
import { setupClaudeCodeSettings } from "./setup-claude-code-settings";
import { validateEnvironmentVariables } from "./validate-env";

interface KubernetesBaseRunnerOptions {
  // Claude Code arguments
  prompt?: string;
  promptFile?: string;
  allowedTools?: string;
  disallowedTools?: string;
  maxTurns?: string;
  mcpConfig?: string;
  systemPrompt?: string;
  appendSystemPrompt?: string;
  model?: string;
  fallbackModel?: string;
  claudeEnv?: string;
  
  // Execution settings
  timeoutMinutes?: string;
  
  // Environment
  workspaceDir?: string;
}

export async function runClaudeCodeBaseAction(options: KubernetesBaseRunnerOptions): Promise<void> {
  const {
    prompt = "",
    promptFile = "",
    allowedTools = "",
    disallowedTools = "",
    maxTurns = "",
    mcpConfig = "",
    systemPrompt = "",
    appendSystemPrompt = "",
    model = "",
    fallbackModel = "",
    claudeEnv = "",
    timeoutMinutes = "10",
    workspaceDir = "/workspace"
  } = options;

  console.log("🚀 Starting Claude Code Base Action (Kubernetes mode)...");

  // Set environment variables that the original action expects
  process.env.INPUT_PROMPT = prompt;
  process.env.INPUT_PROMPT_FILE = promptFile;
  process.env.INPUT_ALLOWED_TOOLS = allowedTools;
  process.env.INPUT_DISALLOWED_TOOLS = disallowedTools;
  process.env.INPUT_MAX_TURNS = maxTurns;
  process.env.INPUT_MCP_CONFIG = mcpConfig;
  process.env.INPUT_SYSTEM_PROMPT = systemPrompt;
  process.env.INPUT_APPEND_SYSTEM_PROMPT = appendSystemPrompt;
  process.env.INPUT_CLAUDE_ENV = claudeEnv;
  process.env.INPUT_TIMEOUT_MINUTES = timeoutMinutes;
  process.env.INPUT_FALLBACK_MODEL = fallbackModel;
  process.env.ANTHROPIC_MODEL = model;
  process.env.RUNNER_TEMP = "/tmp";
  process.env.CLAUDE_CODE_ACTION = "1";

  // Change to workspace directory
  if (workspaceDir !== process.cwd()) {
    process.chdir(workspaceDir);
    console.log(`📁 Changed working directory to: ${workspaceDir}`);
  }

  try {
    // Step 1: Validate environment
    validateEnvironmentVariables();

    // Step 2: Setup Claude Code settings
    await setupClaudeCodeSettings();

    // Step 3: Prepare prompt
    const promptConfig = await preparePrompt({
      prompt: process.env.INPUT_PROMPT || "",
      promptFile: process.env.INPUT_PROMPT_FILE || "",
    });

    console.log(`📝 Prepared prompt file: ${promptConfig.path}`);

    // Step 4: Execute Claude
    await runClaude(promptConfig.path, {
      allowedTools: process.env.INPUT_ALLOWED_TOOLS,
      disallowedTools: process.env.INPUT_DISALLOWED_TOOLS,
      maxTurns: process.env.INPUT_MAX_TURNS,
      mcpConfig: process.env.INPUT_MCP_CONFIG,
      systemPrompt: process.env.INPUT_SYSTEM_PROMPT,
      appendSystemPrompt: process.env.INPUT_APPEND_SYSTEM_PROMPT,
      claudeEnv: process.env.INPUT_CLAUDE_ENV,
      fallbackModel: process.env.INPUT_FALLBACK_MODEL,
      timeoutMinutes: process.env.INPUT_TIMEOUT_MINUTES,
    });

    console.log("✅ Claude Code Base Action completed successfully");

  } catch (error) {
    console.error("❌ Claude Code Base Action failed:", error);
    throw error;
  }
}

// Export for use as a Kubernetes Job entry point
export async function main() {
  try {
    await runClaudeCodeBaseAction({
      prompt: process.env.INPUT_PROMPT,
      promptFile: process.env.INPUT_PROMPT_FILE,
      allowedTools: process.env.INPUT_ALLOWED_TOOLS,
      disallowedTools: process.env.INPUT_DISALLOWED_TOOLS,
      maxTurns: process.env.INPUT_MAX_TURNS,
      mcpConfig: process.env.INPUT_MCP_CONFIG,
      systemPrompt: process.env.INPUT_SYSTEM_PROMPT,
      appendSystemPrompt: process.env.INPUT_APPEND_SYSTEM_PROMPT,
      model: process.env.ANTHROPIC_MODEL,
      fallbackModel: process.env.INPUT_FALLBACK_MODEL,
      claudeEnv: process.env.INPUT_CLAUDE_ENV,
      timeoutMinutes: process.env.INPUT_TIMEOUT_MINUTES,
      workspaceDir: process.env.WORKSPACE_DIR,
    });

    console.log("🎉 Claude Code Base Action completed successfully");
    process.exit(0);

  } catch (error) {
    console.error("💥 Claude Code Base Action failed:", error);
    process.exit(1);
  }
}

// Run if called directly (Kubernetes Job execution)
if (import.meta.main) {
  main();
}