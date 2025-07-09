#!/usr/bin/env bun
/**
 * check-trigger.ts - Determines if Claude should respond
 * 
 * Exactly matches Claude Code Action's trigger detection logic.
 * Checks for trigger phrases like "@claude" and assignee triggers.
 */

import type { ParsedGitHubContext } from "../github/context";

export interface TriggerConfig {
  trigger_phrase: string;
  assignee_trigger?: string;
  direct_prompt?: string;
}

export interface TriggerResult {
  shouldRespond: boolean;
  trigger: 'comment' | 'assignee' | 'direct_prompt' | 'none';
  content?: string;
}

export function checkTrigger(
  context: ParsedGitHubContext,
  config: TriggerConfig
): TriggerResult {
  const {
    trigger_phrase = "@claude",
    assignee_trigger,
    direct_prompt
  } = config;

  // Direct prompt - always triggers (for automated workflows)
  if (direct_prompt) {
    return {
      shouldRespond: true,
      trigger: 'direct_prompt',
      content: direct_prompt
    };
  }

  // Check for assignee trigger (issues only)
  if (assignee_trigger && context.entityType === 'issue') {
    const assignees = context.issue?.assignees || [];
    const hasAssigneeTrigger = assignees.some(assignee => 
      assignee.login === assignee_trigger
    );
    
    if (hasAssigneeTrigger) {
      return {
        shouldRespond: true,
        trigger: 'assignee',
        content: context.issue?.body || ""
      };
    }
  }

  // Check for trigger phrase in comments
  if (context.comment) {
    const commentBody = context.comment.body || "";
    if (commentBody.includes(trigger_phrase)) {
      return {
        shouldRespond: true,
        trigger: 'comment',
        content: commentBody
      };
    }
  }

  // Check for trigger phrase in issue/PR body for opened events
  if (context.entityType === 'issue' && context.issue?.body?.includes(trigger_phrase)) {
    return {
      shouldRespond: true,
      trigger: 'comment',
      content: context.issue.body
    };
  }

  if (context.entityType === 'pull_request' && context.pullRequest?.body?.includes(trigger_phrase)) {
    return {
      shouldRespond: true,
      trigger: 'comment', 
      content: context.pullRequest.body
    };
  }

  // Check for trigger phrase in issue title for opened events
  if (context.entityType === 'issue' && context.issue?.title?.includes(trigger_phrase)) {
    return {
      shouldRespond: true,
      trigger: 'comment',
      content: `${context.issue.title}\n\n${context.issue.body || ""}`
    };
  }

  return {
    shouldRespond: false,
    trigger: 'none'
  };
}