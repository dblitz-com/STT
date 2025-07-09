#!/usr/bin/env bun
/**
 * ⚠️  OPTION B - CUSTOM KUBERNETES IMPLEMENTATION ⚠️
 * 
 * DO NOT USE THIS UNLESS FIXING GITHUB ACTIONS RUNNER ISSUES!
 * 
 * PREFERRED SOLUTION: Use GitHub Actions self-hosted runners (Option A)
 * See refs/claude-code-action and refs/claude-code-base-action for official implementation
 * 
 * This is a custom Kubernetes implementation that attempts to emulate 
 * GitHub Actions environment. It should only be used as a fallback
 * when GitHub Actions runners are not available or need debugging.
 * 
 * Main Claude Runner Entry Point for Kubernetes
 * 
 * This is the primary entry point referenced by the Kubernetes Job template.
 * It delegates to the official claude-code-action's Kubernetes runner.
 */

import { runClaudeCodeAction } from "../claudecode/claudecodeaction/src/entrypoints/kubernetes-runner";

async function main() {
  try {
    console.log("Starting Claude Runner in Kubernetes...");
    
    // Parse environment variables and ConfigMap data
    const options = {
      // GitHub context from webhook
      eventName: process.env.GITHUB_EVENT_NAME || "issue_comment",
      payload: JSON.parse(process.env.GITHUB_EVENT_PAYLOAD || "{}"),
      githubToken: process.env.GITHUB_TOKEN,
      
      // Claude configuration from ConfigMap
      allowedTools: process.env.INPUT_ALLOWED_TOOLS || "",
      disallowedTools: process.env.INPUT_DISALLOWED_TOOLS || "",
      maxTurns: process.env.INPUT_MAX_TURNS || "",
      model: process.env.INPUT_MODEL || "claude-3.5-sonnet",
      fallbackModel: process.env.INPUT_FALLBACK_MODEL || "",
      customInstructions: process.env.INPUT_SYSTEM_PROMPT || "",
      timeoutMinutes: process.env.INPUT_TIMEOUT_MINUTES || "60",
      
      // Workspace directory where repo is cloned
      workspaceDir: process.env.GITHUB_WORKSPACE || "/workspace"
    };
    
    // Check if we have a prompt file
    const promptFile = process.env.PROMPT_FILE || "/tmp/prompt.txt";
    const fs = require("fs");
    
    if (fs.existsSync(promptFile)) {
      const prompt = fs.readFileSync(promptFile, "utf-8");
      console.log("Found prompt file, using as custom instructions");
      options.customInstructions = prompt;
    }
    
    // Run the Claude Code Action
    await runClaudeCodeAction(options);
    
    console.log("Claude Runner completed successfully");
    process.exit(0);
  } catch (error) {
    console.error("Claude Runner failed:", error);
    process.exit(1);
  }
}

// Run the main function
main();