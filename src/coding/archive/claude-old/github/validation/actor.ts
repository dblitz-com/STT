/**
 * Actor Validation for Agentic Coding System
 * 
 * Validates that the actor triggering Claude Code is a human user.
 * Adapted from anthropics/claude-code-action.
 */

import type { Octokit } from "@octokit/rest";
import type { ParsedGitHubContext } from "../context";

/**
 * Check if the actor is a human user (not a bot)
 */
export async function checkHumanActor(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<void> {
  const actor = context.actor;
  
  console.log(`Validating actor: ${actor}`);

  try {
    // Get user information
    const { data: user } = await octokit.users.getByUsername({
      username: actor,
    });

    // Check if user is a bot
    if (user.type === "Bot") {
      throw new Error(`Actor ${actor} is a bot. Only human users can trigger Claude Code.`);
    }

    // Additional bot detection (GitHub Apps often have [bot] suffix)
    if (actor.toLowerCase().includes("[bot]") || actor.toLowerCase().endsWith("-bot")) {
      throw new Error(`Actor ${actor} appears to be a bot. Only human users can trigger Claude Code.`);
    }

    console.log(`✓ Actor ${actor} is a valid human user`);

  } catch (error) {
    if (error instanceof Error && error.message.includes("is a bot")) {
      throw error;
    }
    
    // If we can't fetch user info, log warning but don't block
    console.warn(`Warning: Could not validate actor ${actor}: ${error instanceof Error ? error.message : String(error)}`);
    console.log("Proceeding with caution...");
  }
}

/**
 * Check if actor has sufficient account age
 */
export async function checkActorAccountAge(
  octokit: Octokit,
  context: ParsedGitHubContext,
  minimumDaysOld: number = 30
): Promise<void> {
  const actor = context.actor;

  try {
    const { data: user } = await octokit.users.getByUsername({
      username: actor,
    });

    const accountCreated = new Date(user.created_at);
    const now = new Date();
    const accountAgeInDays = (now.getTime() - accountCreated.getTime()) / (1000 * 60 * 60 * 24);

    if (accountAgeInDays < minimumDaysOld) {
      throw new Error(
        `Actor ${actor}'s account is only ${Math.floor(accountAgeInDays)} days old. ` +
        `Minimum required age is ${minimumDaysOld} days for security.`
      );
    }

    console.log(`✓ Actor ${actor}'s account is ${Math.floor(accountAgeInDays)} days old (sufficient)`);

  } catch (error) {
    if (error instanceof Error && error.message.includes("account is only")) {
      throw error;
    }
    
    console.warn(`Warning: Could not check account age for ${actor}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Check if actor is in allowed users list
 */
export function checkAllowedActor(
  context: ParsedGitHubContext,
  allowedUsers: string[]
): void {
  if (allowedUsers.length === 0) {
    return; // No restrictions
  }

  const actor = context.actor;
  
  if (!allowedUsers.includes(actor)) {
    throw new Error(
      `Actor ${actor} is not in the allowed users list: ${allowedUsers.join(", ")}`
    );
  }

  console.log(`✓ Actor ${actor} is in allowed users list`);
}

/**
 * Comprehensive actor validation
 */
export async function validateActor(
  octokit: Octokit,
  context: ParsedGitHubContext,
  options: {
    allowedUsers?: string[];
    minimumAccountAge?: number;
    requireHuman?: boolean;
  } = {}
): Promise<void> {
  const {
    allowedUsers = [],
    minimumAccountAge = 0,
    requireHuman = true,
  } = options;

  console.log(`Performing comprehensive actor validation for: ${context.actor}`);

  // Check allowed users list
  if (allowedUsers.length > 0) {
    checkAllowedActor(context, allowedUsers);
  }

  // Check if human (not bot)
  if (requireHuman) {
    await checkHumanActor(octokit, context);
  }

  // Check account age
  if (minimumAccountAge > 0) {
    await checkActorAccountAge(octokit, context, minimumAccountAge);
  }

  console.log(`✓ Actor ${context.actor} passed all validation checks`);
}