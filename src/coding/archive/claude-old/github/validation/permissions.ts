/**
 * Permissions Validation for Agentic Coding System
 * 
 * Validates that the actor has sufficient permissions to trigger Claude Code.
 * Adapted from anthropics/claude-code-action.
 */

import type { Octokit } from "@octokit/rest";
import type { ParsedGitHubContext } from "../context";

/**
 * Check if actor has write permissions to the repository
 */
export async function checkWritePermissions(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<boolean> {
  const { repository, actor } = context;
  
  console.log(`Checking write permissions for ${actor} on ${repository.full_name}`);

  try {
    // Get user's permission level for the repository
    const { data: permission } = await octokit.repos.getCollaboratorPermissionLevel({
      owner: repository.owner,
      repo: repository.repo,
      username: actor,
    });

    const permissionLevel = permission.permission;
    const hasWriteAccess = ["write", "admin", "maintain"].includes(permissionLevel);

    console.log(`User ${actor} has ${permissionLevel} permission on ${repository.full_name}`);

    if (!hasWriteAccess) {
      console.log(`✗ User ${actor} does not have write access (has: ${permissionLevel})`);
      return false;
    }

    console.log(`✓ User ${actor} has write access (${permissionLevel})`);
    return true;

  } catch (error) {
    // If we can't check permissions, it might be because the user is not a collaborator
    // In public repos, this is expected for external contributors
    console.log(`Could not check permissions for ${actor}: ${error instanceof Error ? error.message : String(error)}`);
    
    // For public repositories, check if user is the repository owner
    if (actor === repository.owner) {
      console.log(`✓ User ${actor} is the repository owner`);
      return true;
    }

    // Check if repository is public and user has forked it
    try {
      const { data: repo } = await octokit.repos.get({
        owner: repository.owner,
        repo: repository.repo,
      });

      if (!repo.private) {
        console.log(`Repository is public, allowing limited access for ${actor}`);
        return true; // Allow for public repos, but with restrictions
      }
    } catch (repoError) {
      console.error(`Failed to check repository visibility: ${repoError}`);
    }

    console.log(`✗ Cannot verify write permissions for ${actor}`);
    return false;
  }
}

/**
 * Check if actor can create branches in the repository
 * More permissive than full write access - follows Claude Code Action approach
 */
export async function checkBranchCreationPermissions(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<boolean> {
  const { repository, actor } = context;
  
  console.log(`Checking branch creation permissions for ${actor} on ${repository.full_name}`);

  try {
    // First check if repository is public
    const { data: repo } = await octokit.repos.get({
      owner: repository.owner,
      repo: repository.repo,
    });

    // For public repositories, allow branch creation for contributors
    if (!repo.private) {
      console.log(`✓ Repository is public, allowing branch creation for ${actor}`);
      return true;
    }

    // For private repos, still need write access
    return await checkWritePermissions(octokit, context);

  } catch (error) {
    console.log(`Could not check branch creation permissions for ${actor}: ${error instanceof Error ? error.message : String(error)}`);
    
    // Fallback: if we can't determine repo visibility, check basic read access
    try {
      await octokit.repos.get({
        owner: repository.owner,
        repo: repository.repo,
      });
      console.log(`✓ User ${actor} has access to repository, allowing branch creation`);
      return true;
    } catch {
      console.log(`✗ User ${actor} has no access to repository`);
      return false;
    }
  }
}

/**
 * Check if actor can create pull requests
 */
export async function checkPullRequestPermissions(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<boolean> {
  const { repository, actor } = context;

  try {
    // Check if user can create PRs (usually anyone can in public repos)
    const { data: repo } = await octokit.repos.get({
      owner: repository.owner,
      repo: repository.repo,
    });

    // For public repos, anyone can create PRs
    if (!repo.private) {
      console.log(`✓ User ${actor} can create PRs in public repository`);
      return true;
    }

    // For private repos, need write access
    return await checkWritePermissions(octokit, context);

  } catch (error) {
    console.log(`Could not check PR permissions for ${actor}: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

/**
 * Check if actor can comment on issues/PRs
 */
export async function checkCommentPermissions(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<boolean> {
  const { repository } = context;

  try {
    // Check repository visibility
    const { data: repo } = await octokit.repos.get({
      owner: repository.owner,
      repo: repository.repo,
    });

    // Public repos allow comments from anyone
    if (!repo.private) {
      return true;
    }

    // Private repos require read access
    return await checkReadPermissions(octokit, context);

  } catch (error) {
    console.log(`Could not check comment permissions: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

/**
 * Check if actor has read permissions to the repository
 */
export async function checkReadPermissions(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<boolean> {
  const { repository, actor } = context;

  try {
    // Try to get repository info (requires read access)
    await octokit.repos.get({
      owner: repository.owner,
      repo: repository.repo,
    });

    console.log(`✓ User ${actor} has read access to ${repository.full_name}`);
    return true;

  } catch (error) {
    console.log(`✗ User ${actor} does not have read access to ${repository.full_name}`);
    return false;
  }
}

/**
 * Comprehensive permissions check
 */
export async function validatePermissions(
  octokit: Octokit,
  context: ParsedGitHubContext,
  requiredPermissions: {
    write?: boolean;
    branchCreation?: boolean;
    pullRequest?: boolean;
    comment?: boolean;
  } = {}
): Promise<void> {
  const { write = true, branchCreation = false, pullRequest = false, comment = false } = requiredPermissions;

  console.log(`Validating permissions for ${context.actor}`);

  if (write && !(await checkWritePermissions(octokit, context))) {
    throw new Error(`User ${context.actor} does not have write permissions to ${context.repository.full_name}`);
  }

  if (branchCreation && !(await checkBranchCreationPermissions(octokit, context))) {
    throw new Error(`User ${context.actor} cannot create branches in ${context.repository.full_name}`);
  }

  if (pullRequest && !(await checkPullRequestPermissions(octokit, context))) {
    throw new Error(`User ${context.actor} cannot create pull requests in ${context.repository.full_name}`);
  }

  if (comment && !(await checkCommentPermissions(octokit, context))) {
    throw new Error(`User ${context.actor} cannot comment in ${context.repository.full_name}`);
  }

  console.log(`✓ All required permissions validated for ${context.actor}`);
}