/**
 * Trigger Validation for Agentic Coding System
 * 
 * Checks if webhook events contain Claude Code trigger phrases.
 * Adapted from anthropics/claude-code-action.
 */

import type { ParsedGitHubContext } from "../context";

const TRIGGER_PHRASES = [
  "@claude",
  "@claude-code", 
  "claude:",
  "claude-code:",
  "/claude",
  "/claude-code",
];

/**
 * Escape special regex characters
 */
export function escapeRegExp(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Check if the context contains a trigger action for Claude Code
 * Uses regex validation with word boundaries like official Claude Code Action
 */
export async function checkTriggerAction(context: ParsedGitHubContext): Promise<boolean> {
  console.log("Checking for Claude Code trigger phrases...");

  // Get the text to analyze based on event type
  let textToAnalyze = "";

  // For comment events, check the comment body
  if (context.triggerComment) {
    textToAnalyze = context.triggerComment.body;
    console.log(`Analyzing comment: "${textToAnalyze.substring(0, 100)}..."`);
  }
  // For issue/PR creation events, check the body
  else if (context.issue && context.eventName === "issues") {
    textToAnalyze = context.issue.body;
    console.log(`Analyzing issue body: "${textToAnalyze.substring(0, 100)}..."`);
  }
  else if (context.pullRequest && context.eventName === "pull_request") {
    textToAnalyze = context.pullRequest.body;
    console.log(`Analyzing PR body: "${textToAnalyze.substring(0, 100)}..."`);
  }

  if (!textToAnalyze) {
    console.log("No text content found to analyze for triggers");
    return false;
  }

  // Check for trigger phrases with regex validation (like official Claude Code Action)
  for (const trigger of TRIGGER_PHRASES) {
    // Use regex with word boundaries and punctuation requirements
    const escapedTrigger = escapeRegExp(trigger);
    const triggerRegex = new RegExp(`(^|\\s)${escapedTrigger}([\\s.,!?;:]|$)`, 'i');
    
    if (triggerRegex.test(textToAnalyze)) {
      console.log(`✓ Found trigger phrase with proper validation: "${trigger}"`);
      return true;
    }
  }

  console.log("✗ No valid trigger phrases found");
  return false;
}

/**
 * Extract Claude Code instructions from trigger text
 * Only extracts instructions if there's a valid trigger followed by actual instructions
 */
export function extractClaudeInstructions(context: ParsedGitHubContext): string {
  const text = context.triggerComment?.body || 
               context.issue?.body || 
               context.pullRequest?.body || 
               "";

  // Find valid trigger phrase with proper validation
  for (const trigger of TRIGGER_PHRASES) {
    const escapedTrigger = escapeRegExp(trigger);
    const triggerRegex = new RegExp(`(^|\\s)${escapedTrigger}([\\s.,!?;:]|$)`, 'i');
    
    const match = triggerRegex.exec(text);
    if (match) {
      const triggerStart = match.index + match[1].length; // Start of trigger phrase
      const triggerEnd = triggerStart + trigger.length; // End of trigger phrase
      
      // Check what follows the trigger
      const afterTrigger = text.substring(triggerEnd).trim();
      
      // Remove common prefixes like ":" or punctuation
      const cleanedInstructions = afterTrigger.replace(/^[:\-\s.,!?;]+/, "").trim();
      
      // Only return instructions if there's actual content after the trigger
      if (cleanedInstructions && cleanedInstructions.length > 0) {
        return cleanedInstructions;
      }
      
      // If no instructions after a valid trigger, return default message
      return "Please help with this issue.";
    }
  }

  return "Please help with this issue.";
}

/**
 * Check if trigger is from authorized user
 */
export function isTriggerFromAuthorizedUser(
  context: ParsedGitHubContext,
  authorizedUsers?: string[]
): boolean {
  if (!authorizedUsers || authorizedUsers.length === 0) {
    return true; // No restrictions
  }

  const triggerUser = context.triggerComment?.user || context.actor;
  return authorizedUsers.includes(triggerUser);
}