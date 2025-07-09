#!/usr/bin/env bun
/**
 * ⚠️  OPTION B - CUSTOM KUBERNETES IMPLEMENTATION ⚠️
 * 
 * DO NOT USE THIS UNLESS FIXING GITHUB ACTIONS RUNNER ISSUES!
 * 
 * PREFERRED SOLUTION: Use GitHub Actions self-hosted runners (Option A)
 * See refs/claude-code-action and refs/claude-code-base-action for official implementation
 * 
 * This is a custom attempt to emulate GitHub Actions workflow in Kubernetes.
 * It lacks proper GitHub Actions context and status comment formatting.
 * 
 * Kubernetes Runner for Claude Code Action
 * 
 * Replaces GitHub Actions workflow with Kubernetes Job execution.
 * This mimics the exact behavior of the official claude-code-action
 * but runs in our Kubernetes infrastructure instead.
 */

import { preparePrompt } from "../create-prompt";
import { prepareMcpConfig } from "../mcp/install-mcp-server";
import { parseWebhookContext } from "../github/context";
import { fetchGitHubData } from "../github/data/fetcher";
import { checkTriggerAction } from "../github/validation/trigger";
import { checkHumanActor } from "../github/validation/actor";
import { checkBranchCreationPermissions } from "../github/validation/permissions";
import { createInitialComment } from "../github/operations/comments/create-initial";
import { setupBranch } from "../github/operations/branch";
import { updateTrackingComment } from "../github/operations/comments/update-with-branch";
import { runClaude } from "../../claudecodebaseaction/src/run-claude";
import { createOctokit } from "../github/api/client";
import { setupGitHubToken } from "../github/token";

interface KubernetesRunnerOptions {
  // GitHub event context (from webhook or manual trigger)
  eventName: string;
  payload: any;
  githubToken?: string;
  
  // Claude configuration
  allowedTools?: string;
  disallowedTools?: string;
  maxTurns?: string;
  model?: string;
  fallbackModel?: string;
  customInstructions?: string;
  timeoutMinutes?: string;
  
  // Infrastructure settings
  workspaceDir?: string;
}

export async function runClaudeCodeAction(options: KubernetesRunnerOptions): Promise<void> {
  const {
    eventName,
    payload,
    githubToken,
    allowedTools = "",
    disallowedTools = "",
    maxTurns = "",
    model = "",
    fallbackModel = "",
    customInstructions = "",
    timeoutMinutes = "30",
    workspaceDir = "/workspace"
  } = options;

  console.log("🚀 Starting Claude Code Action (Kubernetes mode)...");

  // Step 1: Setup GitHub token and client
  const token = githubToken || await setupGitHubToken();
  const octokit = createOctokit(token);

  // Step 2: Parse webhook context (same as GitHub Actions context)
  const context = parseWebhookContext(payload, eventName);
  console.log(`📋 Parsed context: ${context.isPR ? 'PR' : 'Issue'} #${context.entityNumber}`);

  // Step 3: Check trigger conditions (same as prepare.ts)
  const containsTrigger = await checkTriggerAction(context);
  if (!containsTrigger) {
    console.log("ℹ️ No trigger found, skipping Claude Code execution");
    return;
  }

  // Step 4: Validate permissions
  await checkHumanActor(octokit.rest, context);
  const canCreateBranches = await checkBranchCreationPermissions(octokit.rest, context);
  if (!canCreateBranches) {
    throw new Error("Actor cannot create branches in the repository");
  }

  // Step 5: Create initial tracking comment
  const commentId = await createInitialComment(octokit.rest, context);
  console.log(`💬 Created tracking comment: ${commentId}`);

  // Step 6: Setup branch for work
  const branchInfo = await setupBranch(octokit.rest, context);
  console.log(`🌿 Working on branch: ${branchInfo.name}`);

  // Step 7: Update comment with branch info
  await updateTrackingComment(octokit.rest, {
    ...context,
    claudeCommentId: commentId,
    branchName: branchInfo.name,
    branchUrl: branchInfo.url,
  });

  // Step 8: Fetch GitHub data for context
  const githubData = await fetchGitHubData({
    octokits: octokit,
    context,
    allowedTools: allowedTools.split(',').filter(Boolean),
  });

  // Step 9: Prepare MCP configuration 
  const mcpConfig = await prepareMcpConfig({
    githubToken: token,
    owner: context.repo.owner,
    repo: context.repo.repo,
    branch: branchInfo.name,
    additionalMcpConfig: "",
    claudeCommentId: commentId.toString(),
    allowedTools: allowedTools.split(',').filter(Boolean),
    context
  });

  // Write MCP config to file for claude-code-base-action
  await Bun.write('/tmp/mcp-config.json', mcpConfig);

  // Step 10: Create prompt for Claude
  const prompt = await preparePrompt({
    context,
    githubData,
    allowedTools: allowedTools.split(',').filter(Boolean),
    customInstructions,
  });

  // Write prompt to file for claude-code-base-action
  await Bun.write('/tmp/claude-prompt.txt', prompt);

  // Step 11: Execute Claude using claude-code-base-action pattern
  try {
    console.log("🤖 Executing Claude Code...");
    
    // Set environment variables for claude-code-base-action
    process.env.RUNNER_TEMP = "/tmp";
    process.env.ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
    process.env.GITHUB_TOKEN = token;
    process.env.CLAUDE_COMMENT_ID = commentId.toString();
    process.env.REPO_OWNER = context.repo.owner;
    process.env.REPO_NAME = context.repo.repo;
    process.env.BRANCH_NAME = branchInfo.name;
    process.env.REPO_DIR = workspaceDir;
    process.env.IS_PR = context.isPR ? "true" : "false";

    await runClaude('/tmp/claude-prompt.txt', {
      allowedTools,
      disallowedTools,
      maxTurns,
      mcpConfig: '/tmp/mcp-config.json',
      fallbackModel,
      timeoutMinutes,
    });

    console.log("✅ Claude Code execution completed successfully");

  } catch (error) {
    console.error("❌ Claude Code execution failed:", error);
    
    // Update comment with failure status
    await updateTrackingComment(octokit.rest, {
      ...context,
      claudeCommentId: commentId,
      branchName: branchInfo.name,
      branchUrl: branchInfo.url,
      status: 'failed',
      error: error instanceof Error ? error.message : String(error),
    });

    throw error;
  }
}

// Export for use as a Kubernetes Job entry point
export async function main() {
  try {
    // Read configuration from environment variables (set by Kubernetes ConfigMap/Secrets)
    const eventName = process.env.GITHUB_EVENT_NAME || "issues";
    const payloadJson = process.env.GITHUB_PAYLOAD || "{}";
    const payload = JSON.parse(payloadJson);

    await runClaudeCodeAction({
      eventName,
      payload,
      githubToken: process.env.GITHUB_TOKEN,
      allowedTools: process.env.ALLOWED_TOOLS || "",
      disallowedTools: process.env.DISALLOWED_TOOLS || "",
      maxTurns: process.env.MAX_TURNS || "",
      model: process.env.ANTHROPIC_MODEL || "",
      fallbackModel: process.env.FALLBACK_MODEL || "",
      customInstructions: process.env.CUSTOM_INSTRUCTIONS || "",
      timeoutMinutes: process.env.TIMEOUT_MINUTES || "30",
      workspaceDir: process.env.WORKSPACE_DIR || "/workspace",
    });

    console.log("🎉 Claude Code Action completed successfully");
    process.exit(0);

  } catch (error) {
    console.error("💥 Claude Code Action failed:", error);
    process.exit(1);
  }
}

// Run if called directly (Kubernetes Job execution)
if (import.meta.main) {
  main();
}