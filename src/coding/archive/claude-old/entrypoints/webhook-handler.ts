#!/usr/bin/env bun
/**
 * Webhook Handler for Agentic Coding System
 * 
 * Receives GitHub webhook events and triggers Claude Code execution via Kubernetes Jobs.
 * Adapted from anthropics/claude-code-action for our FluxCD/Kubernetes infrastructure.
 * 
 * Related to GitHub Issue #15: Implement Agentic Coding System with Claude Code SDK Python Runtime
 */

import { createOctokit } from "../github/api/client";
import { setupGitHubToken } from "../github/token";
import { checkTriggerAction } from "../github/validation/trigger";
import { checkHumanActor } from "../github/validation/actor";
import { checkBranchCreationPermissions } from "../github/validation/permissions";
import { createInitialComment } from "../github/operations/comments/create-initial";
import { setupBranch } from "../github/operations/branch";
import { updateTrackingComment } from "../github/operations/comments/update-with-branch";
import { prepareMcpConfig } from "../mcp/install-mcp-server";
import { createPrompt } from "../create-prompt";
import { fetchGitHubData } from "../github/data/fetcher";
import { parseWebhookContext } from "../github/context";
import { submitKubernetesJob } from "./kubernetes-runner";

export interface WebhookPayload {
  action: string;
  issue?: {
    number: number;
    title: string;
    body: string;
    assignee?: { login: string };
    user: { login: string };
  };
  pull_request?: {
    number: number;
    title: string;
    body: string;
    user: { login: string };
  };
  comment?: {
    id: number;
    body: string;
    user: { login: string };
  };
  repository: {
    full_name: string;
    owner: { login: string };
    name: string;
    clone_url: string;
  };
  sender: { login: string };
}

export async function handleWebhook(
  payload: WebhookPayload,
  eventName: string,
  githubToken?: string
): Promise<{ success: boolean; message: string; jobId?: string }> {
  try {
    console.log(`Processing ${eventName} webhook event`);
    
    // Step 1: Setup GitHub token
    const token = githubToken || await setupGitHubToken();
    const octokit = createOctokit(token);

    // Step 2: Parse webhook context (similar to GitHub Actions context)
    const context = parseWebhookContext(payload, eventName);

    // Step 3: Check branch creation permissions (like Claude Code Action)
    // We don't need full write access, just ability to create branches
    const canCreateBranches = await checkBranchCreationPermissions(
      octokit.rest,
      context,
    );
    if (!canCreateBranches) {
      throw new Error(
        "Actor cannot create branches in the repository"
      );
    }

    // Step 4: Check trigger conditions
    const containsTrigger = await checkTriggerAction(context);

    if (!containsTrigger) {
      console.log("No trigger found, skipping Claude Code execution");
      return { 
        success: true, 
        message: "No trigger phrase found in event" 
      };
    }

    // Step 5: Check if actor is human
    await checkHumanActor(octokit.rest, context);

    // Step 6: Create initial tracking comment
    const commentId = await createInitialComment(octokit.rest, context);

    // Step 7: Fetch GitHub data for context
    const githubData = await fetchGitHubData({
      octokits: octokit,
      repository: `${context.repository.owner}/${context.repository.repo}`,
      prNumber: context.entityNumber.toString(),
      isPR: context.isPR,
      triggerUsername: context.actor,
    });

    // Step 8: Setup branch
    const branchInfo = await setupBranch(octokit, githubData, context);

    // Step 9: Update initial comment with branch link
    if (branchInfo.claudeBranch) {
      await updateTrackingComment(
        octokit,
        context,
        commentId,
        branchInfo.claudeBranch,
      );
    }

    // Step 10: Create prompt file for Claude Code
    const promptInfo = await createPrompt(
      commentId,
      branchInfo.baseBranch,
      branchInfo.claudeBranch,
      githubData,
      context,
    );

    // Step 11: Prepare MCP configuration with our custom servers
    const mcpConfig = await prepareMcpConfig({
      githubToken: token,
      owner: context.repository.owner,
      repo: context.repository.repo,
      branch: branchInfo.currentBranch,
      additionalMcpConfig: "", // Could be passed from webhook
      claudeCommentId: commentId.toString(),
      allowedTools: context.inputs.allowedTools,
      context,
    });

    // Step 12: Submit Kubernetes job for Claude Code execution
    const jobId = await submitKubernetesJob({
      promptFile: promptInfo.promptFile,
      mcpConfig,
      repository: context.repository,
      githubToken: token,
      commentId: commentId.toString(),
      branchInfo,
      context
    });

    console.log(`Successfully submitted Kubernetes job: ${jobId}`);

    return {
      success: true,
      message: `Claude Code job submitted with ID: ${jobId}`,
      jobId
    };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`Webhook handler failed: ${errorMessage}`);
    
    return {
      success: false,
      message: `Failed to process webhook: ${errorMessage}`
    };
  }
}

// Export for use in webhook server
export default handleWebhook;