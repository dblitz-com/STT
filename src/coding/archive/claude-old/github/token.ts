/**
 * GitHub Token Setup for Agentic Coding System
 * 
 * Handles GitHub token retrieval from environment or GitHub App.
 * Adapted from anthropics/claude-code-action.
 */

import { createOctokitWithApp } from "./api/client";

/**
 * Setup GitHub token for API access
 * Prioritizes personal access token, falls back to GitHub App
 */
export async function setupGitHubToken(): Promise<string> {
  // Try personal access token first
  const token = process.env.GITHUB_TOKEN;
  if (token) {
    console.log("Using GitHub personal access token");
    return token;
  }

  // Try GitHub App authentication
  const appId = process.env.GITHUB_APP_ID;
  const privateKey = process.env.GITHUB_PRIVATE_KEY;
  const installationId = process.env.GITHUB_INSTALLATION_ID;

  if (appId && privateKey && installationId) {
    console.log("Using GitHub App authentication");
    
    try {
      const octokit = createOctokitWithApp(appId, privateKey, installationId);
      
      // Get an installation access token
      const { data } = await octokit.rest.apps.createInstallationAccessToken({
        installation_id: parseInt(installationId),
      });

      return data.token;
    } catch (error) {
      throw new Error(
        `Failed to create GitHub App installation token: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  throw new Error(
    "No GitHub authentication available. Set GITHUB_TOKEN or configure GitHub App with GITHUB_APP_ID, GITHUB_PRIVATE_KEY, and GITHUB_INSTALLATION_ID"
  );
}

/**
 * Validate that the token has required permissions
 */
export async function validateTokenPermissions(token: string): Promise<void> {
  const { Octokit } = await import("@octokit/rest");
  const octokit = new Octokit({ auth: token });

  try {
    // Test basic API access
    await octokit.rest.users.getAuthenticated();
    console.log("GitHub token validation successful");
  } catch (error) {
    throw new Error(
      `GitHub token validation failed: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}