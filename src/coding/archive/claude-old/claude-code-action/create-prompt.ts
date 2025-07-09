#!/usr/bin/env bun
/**
 * create-prompt.ts - Generates contextual prompts
 * 
 * Exactly matches Claude Code Action's prompt generation logic.
 * Creates prompts with GitHub context and custom instructions.
 */

import type { ParsedGitHubContext } from "../github/context";
import type { TriggerResult } from "./check-trigger";

export interface PromptConfig {
  custom_instructions?: string;
  claude_env?: Record<string, string>;
  max_turns?: number;
}

export interface GeneratedPrompt {
  content: string;
  isDirectPrompt: boolean;
}

export function createPrompt(
  context: ParsedGitHubContext,
  trigger: TriggerResult,
  config: PromptConfig = {}
): GeneratedPrompt {
  const {
    custom_instructions,
    claude_env,
    max_turns
  } = config;

  let prompt = "";
  const isDirectPrompt = trigger.trigger === 'direct_prompt';

  // Add GitHub context header
  prompt += `# GitHub Context\n\n`;
  
  if (context.entityType === 'issue') {
    prompt += `## Issue #${context.issue?.number}\n`;
    prompt += `**Title:** ${context.issue?.title}\n`;
    prompt += `**Author:** @${context.issue?.user?.login}\n`;
    prompt += `**State:** ${context.issue?.state}\n\n`;
    
    if (context.issue?.body) {
      prompt += `**Description:**\n${context.issue.body}\n\n`;
    }
  } else if (context.entityType === 'pull_request') {
    prompt += `## Pull Request #${context.pullRequest?.number}\n`;
    prompt += `**Title:** ${context.pullRequest?.title}\n`;
    prompt += `**Author:** @${context.pullRequest?.user?.login}\n`;
    prompt += `**State:** ${context.pullRequest?.state}\n`;
    prompt += `**Base:** ${context.pullRequest?.base?.ref} ← **Head:** ${context.pullRequest?.head?.ref}\n\n`;
    
    if (context.pullRequest?.body) {
      prompt += `**Description:**\n${context.pullRequest.body}\n\n`;
    }
  }

  // Add comment context if present
  if (context.comment && trigger.trigger === 'comment') {
    prompt += `## Comment\n`;
    prompt += `**Author:** @${context.comment.user?.login}\n`;
    prompt += `**Content:**\n${context.comment.body}\n\n`;
  }

  // Add repository context
  prompt += `## Repository\n`;
  prompt += `**Name:** ${context.repository?.full_name}\n`;
  prompt += `**Branch:** ${context.repository?.default_branch}\n\n`;

  // Add the actual user request/trigger content
  if (trigger.content) {
    if (isDirectPrompt) {
      prompt += `# Task\n\n${trigger.content}\n\n`;
    } else {
      // Extract the actual request after the trigger phrase
      const triggerPhrase = "@claude";
      const content = trigger.content;
      const triggerIndex = content.indexOf(triggerPhrase);
      
      if (triggerIndex !== -1) {
        const request = content.substring(triggerIndex + triggerPhrase.length).trim();
        if (request) {
          prompt += `# User Request\n\n${request}\n\n`;
        }
      }
    }
  }

  // Add custom instructions if provided
  if (custom_instructions) {
    prompt += `# Additional Instructions\n\n${custom_instructions}\n\n`;
  }

  // Add environment variables context if provided
  if (claude_env && Object.keys(claude_env).length > 0) {
    prompt += `# Environment Variables\n\n`;
    for (const [key, value] of Object.entries(claude_env)) {
      prompt += `- ${key}=${value}\n`;
    }
    prompt += '\n';
  }

  // Add conversation limits if specified
  if (max_turns) {
    prompt += `# Conversation Limits\n\nThis conversation is limited to ${max_turns} turns. Please be concise and efficient.\n\n`;
  }

  // Add standard Claude Code instructions
  prompt += `# Instructions\n\n`;
  prompt += `You are Claude Code, helping with this GitHub ${context.entityType}. `;
  prompt += `You have access to various tools for code analysis, editing, and repository management. `;
  prompt += `Please analyze the context and provide helpful assistance.\n\n`;

  return {
    content: prompt.trim(),
    isDirectPrompt
  };
}