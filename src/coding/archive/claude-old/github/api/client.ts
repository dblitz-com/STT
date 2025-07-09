/**
 * GitHub API Client for Agentic Coding System
 * 
 * Creates Octokit instances for GitHub API interactions.
 * Adapted from anthropics/claude-code-action.
 */

import { Octokit } from "@octokit/rest";
import { createAppAuth } from "@octokit/auth-app";

export interface OctokitInstance {
  rest: Octokit;
  graphql: any;
}

/**
 * Create an Octokit instance with authentication
 */
export function createOctokit(token: string): OctokitInstance {
  const octokit = new Octokit({
    auth: token,
    userAgent: "agentic-coding-system/1.0.0",
  });

  return {
    rest: octokit,
    graphql: octokit.graphql,
  };
}

/**
 * Create an Octokit instance using GitHub App authentication
 */
export function createOctokitWithApp(
  appId: string,
  privateKey: string,
  installationId: string
): OctokitInstance {
  const octokit = new Octokit({
    authStrategy: createAppAuth,
    auth: {
      appId,
      privateKey,
      installationId,
    },
    userAgent: "agentic-coding-system/1.0.0",
  });

  return {
    rest: octokit,
    graphql: octokit.graphql,
  };
}

/**
 * Get installation ID for a repository using GitHub App
 */
export async function getInstallationId(
  appOctokit: Octokit,
  owner: string,
  repo: string
): Promise<number> {
  try {
    const { data } = await appOctokit.rest.apps.getRepoInstallation({
      owner,
      repo,
    });
    return data.id;
  } catch (error) {
    throw new Error(
      `Failed to get installation ID for ${owner}/${repo}: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}