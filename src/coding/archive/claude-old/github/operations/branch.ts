/**
 * Branch Operations for Agentic Coding System
 * 
 * Manages branch creation and setup for Claude Code execution.
 * Adapted from anthropics/claude-code-action.
 */

import type { OctokitInstance } from "../api/client";
import type { ParsedGitHubContext } from "../context";
import type { BranchInfo } from "../../entrypoints/nomad-runner";

export interface GitHubData {
  repository: {
    owner: string;
    name: string;
    defaultBranch: string;
  };
  pullRequest?: {
    number: number;
    head: {
      ref: string;
      sha: string;
    };
    base: {
      ref: string;
      sha: string;
    };
  };
  issue?: {
    number: number;
  };
}

/**
 * Setup branch for Claude Code execution
 */
export async function setupBranch(
  octokit: OctokitInstance,
  githubData: GitHubData,
  context: ParsedGitHubContext
): Promise<BranchInfo> {
  const { repository } = context;

  console.log(`Setting up branch for ${repository.full_name}`);

  try {
    // Determine base branch
    const baseBranch = determineBaseBranch(githubData, context);
    console.log(`Using base branch: ${baseBranch}`);

    // Get base branch SHA
    const baseSha = await getBranchSha(octokit, repository, baseBranch);
    console.log(`Base branch SHA: ${baseSha}`);

    // Generate branch name
    const claudeBranch = generateBranchName(context);
    console.log(`Creating Claude branch: ${claudeBranch}`);

    // Create the branch
    await createBranch(octokit, repository, claudeBranch, baseSha);

    return {
      baseBranch,
      claudeBranch,
      currentBranch: claudeBranch,
    };

  } catch (error) {
    console.error(`Failed to setup branch: ${error instanceof Error ? error.message : String(error)}`);
    
    // Return minimal branch info for fallback
    const baseBranch = githubData.repository.defaultBranch || "main";
    return {
      baseBranch,
      currentBranch: baseBranch,
    };
  }
}

/**
 * Determine the appropriate base branch
 */
function determineBaseBranch(githubData: GitHubData, context: ParsedGitHubContext): string {
  // For PRs, use the PR's base branch
  if (context.isPR && githubData.pullRequest) {
    return githubData.pullRequest.base.ref;
  }

  // For issues or other events, use the repository's default branch
  return githubData.repository.defaultBranch || "main";
}

/**
 * Get the SHA of a branch
 */
async function getBranchSha(
  octokit: OctokitInstance,
  repository: { owner: string; repo: string },
  branchName: string
): Promise<string> {
  try {
    const { data: ref } = await octokit.rest.git.getRef({
      owner: repository.owner,
      repo: repository.repo,
      ref: `heads/${branchName}`,
    });

    return ref.object.sha;

  } catch (error) {
    throw new Error(`Failed to get SHA for branch ${branchName}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Generate a unique branch name for Claude Code
 */
function generateBranchName(context: ParsedGitHubContext): string {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const entityNumber = context.entityNumber || "unknown";
  const entityType = context.isPR ? "pr" : "issue";

  return `claude-code/${entityType}-${entityNumber}-${timestamp}`;
}

/**
 * Create a new branch
 */
async function createBranch(
  octokit: OctokitInstance,
  repository: { owner: string; repo: string },
  branchName: string,
  baseSha: string
): Promise<void> {
  try {
    // Check if branch already exists
    try {
      await octokit.rest.git.getRef({
        owner: repository.owner,
        repo: repository.repo,
        ref: `heads/${branchName}`,
      });

      console.log(`Branch ${branchName} already exists, using existing branch`);
      return;

    } catch (error) {
      // Branch doesn't exist, create it
      console.log(`Creating new branch: ${branchName}`);
    }

    // Create the branch
    await octokit.rest.git.createRef({
      owner: repository.owner,
      repo: repository.repo,
      ref: `refs/heads/${branchName}`,
      sha: baseSha,
    });

    console.log(`✓ Successfully created branch: ${branchName}`);

  } catch (error) {
    throw new Error(`Failed to create branch ${branchName}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Delete a Claude Code branch (cleanup)
 */
export async function deleteBranch(
  octokit: OctokitInstance,
  repository: { owner: string; repo: string },
  branchName: string
): Promise<void> {
  try {
    await octokit.rest.git.deleteRef({
      owner: repository.owner,
      repo: repository.repo,
      ref: `heads/${branchName}`,
    });

    console.log(`✓ Deleted branch: ${branchName}`);

  } catch (error) {
    console.warn(`Failed to delete branch ${branchName}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Check if a branch exists
 */
export async function branchExists(
  octokit: OctokitInstance,
  repository: { owner: string; repo: string },
  branchName: string
): Promise<boolean> {
  try {
    await octokit.rest.git.getRef({
      owner: repository.owner,
      repo: repository.repo,
      ref: `heads/${branchName}`,
    });

    return true;

  } catch (error) {
    return false;
  }
}

/**
 * List all Claude Code branches in repository
 */
export async function listClaudeCodeBranches(
  octokit: OctokitInstance,
  repository: { owner: string; repo: string }
): Promise<string[]> {
  try {
    const { data: refs } = await octokit.rest.git.listMatchingRefs({
      owner: repository.owner,
      repo: repository.repo,
      ref: "heads/claude-code/",
    });

    return refs.map(ref => ref.ref.replace("refs/heads/", ""));

  } catch (error) {
    console.warn(`Failed to list Claude Code branches: ${error instanceof Error ? error.message : String(error)}`);
    return [];
  }
}