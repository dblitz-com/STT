#!/usr/bin/env bun
/**
 * Local version of Claude Code Action's prepare.ts
 * 
 * Exactly matches their logic but adapted for local execution instead of GitHub Actions
 */

import { setupGitHubToken } from "./github/token";
import { checkTriggerAction } from "./github/validation/trigger";
import { checkHumanActor } from "./github/validation/actor";
import { checkWritePermissions } from "./github/validation/permissions";
import { createInitialComment } from "./github/operations/comments/create-initial";
import { setupBranch } from "./github/operations/branch";
import { updateTrackingComment } from "./github/operations/comments/update-with-branch";
import { prepareMcpConfig } from "./mcp/install-mcp-server";
import { createPrompt } from "./create-prompt";
import { createOctokit } from "./github/api/client";
import { fetchGitHubData } from "./github/data/fetcher";
import { parseGitHubContext } from "./github/context";
import type { ParsedGitHubContext } from "./github/context";

export interface LocalPrepareConfig {
  trigger_phrase?: string;
  assignee_trigger?: string;
  label_trigger?: string;
  base_branch?: string;
  branch_prefix?: string;
  allowed_tools?: string;
  disallowed_tools?: string;
  custom_instructions?: string;
  direct_prompt?: string;
  mcp_config?: string;
  github_token?: string;
  additional_permissions?: string;
  use_sticky_comment?: string;
}

export interface LocalPrepareResult {
  shouldContinue: boolean;
  commentId?: number;
  branchInfo?: {
    baseBranch: string;
    claudeBranch?: string;
    currentBranch: string;
  };
  promptFile?: string;
  mcpConfig?: string;
  context?: ParsedGitHubContext;
}

export async function localPrepare(
  webhookPayload: any,
  config: LocalPrepareConfig = {}
): Promise<LocalPrepareResult> {
  try {
    // Set environment variables to match GitHub Actions format
    process.env.TRIGGER_PHRASE = config.trigger_phrase || "@claude";
    process.env.ASSIGNEE_TRIGGER = config.assignee_trigger || "";
    process.env.LABEL_TRIGGER = config.label_trigger || "claude";
    process.env.BASE_BRANCH = config.base_branch || "";
    process.env.BRANCH_PREFIX = config.branch_prefix || "claude/";
    process.env.ALLOWED_TOOLS = config.allowed_tools || "";
    process.env.DISALLOWED_TOOLS = config.disallowed_tools || "";
    process.env.CUSTOM_INSTRUCTIONS = config.custom_instructions || "";
    process.env.DIRECT_PROMPT = config.direct_prompt || "";
    process.env.MCP_CONFIG = config.mcp_config || "";
    process.env.OVERRIDE_GITHUB_TOKEN = config.github_token || "";
    process.env.USE_STICKY_COMMENT = config.use_sticky_comment || "false";
    process.env.ADDITIONAL_PERMISSIONS = config.additional_permissions || "";
    
    // Set GitHub context from webhook payload
    process.env.GITHUB_EVENT_NAME = webhookPayload.action ? 
      `${webhookPayload.action}` : "issue_comment";
    process.env.GITHUB_EVENT_PATH = "/tmp/github_event.json";
    
    // Write webhook payload as GitHub event
    await Bun.write(process.env.GITHUB_EVENT_PATH, JSON.stringify(webhookPayload, null, 2));
    
    // Set repository context
    if (webhookPayload.repository) {
      process.env.GITHUB_REPOSITORY = webhookPayload.repository.full_name;
      process.env.GITHUB_REPOSITORY_OWNER = webhookPayload.repository.owner.login;
      process.env.GITHUB_REPOSITORY_ID = webhookPayload.repository.id.toString();
    }

    // Step 1: Setup GitHub token
    const githubToken = await setupGitHubToken();
    const octokit = createOctokit(githubToken);

    // Step 2: Parse GitHub context (once for all operations)
    const context = parseGitHubContext();

    // Step 3: Check write permissions
    const hasWritePermissions = await checkWritePermissions(
      octokit.rest,
      context,
    );
    if (!hasWritePermissions) {
      throw new Error(
        "Actor does not have write permissions to the repository",
      );
    }

    // Step 4: Check trigger conditions
    const containsTrigger = await checkTriggerAction(context);

    if (!containsTrigger) {
      console.log("No trigger found, skipping remaining steps");
      return { shouldContinue: false };
    }

    // Step 5: Check if actor is human
    await checkHumanActor(octokit.rest, context);

    // Step 6: Create initial tracking comment
    const commentId = await createInitialComment(octokit.rest, context);

    // Step 7: Fetch GitHub data (once for both branch setup and prompt creation)
    const githubData = await fetchGitHubData({
      octokits: octokit,
      repository: `${context.repository.owner}/${context.repository.repo}`,
      prNumber: context.entityNumber.toString(),
      isPR: context.isPR,
      triggerUsername: context.actor,
    });

    // Step 8: Setup branch
    const branchInfo = await setupBranch(octokit, githubData, context);

    // Step 9: Update initial comment with branch link (only for issues that created a new branch)
    if (branchInfo.claudeBranch) {
      await updateTrackingComment(
        octokit,
        context,
        commentId,
        branchInfo.claudeBranch,
      );
    }

    // Step 10: Create prompt file
    const promptPath = "/tmp/claude-prompts/claude-prompt.txt";
    await createPrompt(
      commentId,
      branchInfo.baseBranch,
      branchInfo.claudeBranch,
      githubData,
      context,
    );

    // Step 11: Get MCP configuration
    const additionalMcpConfig = process.env.MCP_CONFIG || "";
    const mcpConfig = await prepareMcpConfig({
      githubToken,
      owner: context.repository.owner,
      repo: context.repository.repo,
      branch: branchInfo.currentBranch,
      additionalMcpConfig,
      claudeCommentId: commentId.toString(),
      allowedTools: context.inputs.allowedTools,
      context,
    });

    return {
      shouldContinue: true,
      commentId,
      branchInfo,
      promptFile: promptPath,
      mcpConfig,
      context
    };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`Local prepare step failed with error: ${errorMessage}`);
    throw error;
  }
}