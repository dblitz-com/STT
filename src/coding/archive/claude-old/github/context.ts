/**
 * GitHub Context Parser for Agentic Coding System
 * 
 * Parses webhook payloads into structured context objects.
 * Adapted from anthropics/claude-code-action GitHub Actions context.
 */

import type { WebhookPayload } from "../entrypoints/webhook-handler";

export interface ParsedGitHubContext {
  repository: {
    owner: string;
    repo: string;
    full_name: string;
    clone_url?: string;
  };
  actor: string;
  entityNumber?: number;
  isPR: boolean;
  eventName: string;
  inputs: {
    allowedTools?: string[];
  };
  triggerComment?: {
    id: number;
    body: string;
    user: string;
  };
  issue?: {
    number: number;
    title: string;
    body: string;
    assignee?: string;
    user: string;
  };
  pullRequest?: {
    number: number;
    title: string;
    body: string;
    user: string;
  };
}

/**
 * Parse webhook payload into GitHub context
 */
export function parseWebhookContext(
  payload: WebhookPayload,
  eventName: string
): ParsedGitHubContext {
  const context: ParsedGitHubContext = {
    repository: {
      owner: payload.repository.owner.login,
      repo: payload.repository.name,
      full_name: payload.repository.full_name,
      clone_url: payload.repository.clone_url,
    },
    actor: payload.sender.login,
    eventName,
    isPR: eventName.includes("pull_request"),
    inputs: {
      allowedTools: [], // Can be extended based on webhook configuration
    },
  };

  // Handle issue events
  if (payload.issue) {
    context.issue = {
      number: payload.issue.number,
      title: payload.issue.title,
      body: payload.issue.body,
      assignee: payload.issue.assignee?.login,
      user: payload.issue.user.login,
    };
    context.entityNumber = payload.issue.number;
  }

  // Handle pull request events
  if (payload.pull_request) {
    context.pullRequest = {
      number: payload.pull_request.number,
      title: payload.pull_request.title,
      body: payload.pull_request.body,
      user: payload.pull_request.user.login,
    };
    context.entityNumber = payload.pull_request.number;
    context.isPR = true;
  }

  // Handle comment events
  if (payload.comment) {
    context.triggerComment = {
      id: payload.comment.id,
      body: payload.comment.body,
      user: payload.comment.user.login,
    };
  }

  return context;
}

/**
 * Get entity type from context
 */
export function getEntityType(context: ParsedGitHubContext): "issue" | "pull_request" {
  return context.isPR ? "pull_request" : "issue";
}

/**
 * Get entity URL from context
 */
export function getEntityUrl(context: ParsedGitHubContext): string {
  const entityType = getEntityType(context);
  const entityNumber = context.entityNumber;
  
  return `https://github.com/${context.repository.full_name}/${entityType}s/${entityNumber}`;
}

/**
 * Check if context contains Claude Code trigger
 */
export function containsClaudeCodeTrigger(context: ParsedGitHubContext): boolean {
  const triggers = ["@claude", "@claude-code", "claude:", "claude-code:"];
  
  // Check comment body
  if (context.triggerComment) {
    return triggers.some(trigger => 
      context.triggerComment!.body.toLowerCase().includes(trigger.toLowerCase())
    );
  }

  // Check issue/PR body for initial creation events
  const bodyToCheck = context.issue?.body || context.pullRequest?.body || "";
  return triggers.some(trigger => 
    bodyToCheck.toLowerCase().includes(trigger.toLowerCase())
  );
}