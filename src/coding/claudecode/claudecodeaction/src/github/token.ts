#!/usr/bin/env bun

/**
 * Simplified GitHub token setup for Kubernetes environment
 * No OIDC token exchange - directly uses provided GitHub token
 */

export async function setupGitHubToken(): Promise<string> {
  // Check for GitHub token in environment variables
  const githubToken = 
    process.env.GITHUB_TOKEN || 
    process.env.OVERRIDE_GITHUB_TOKEN;

  if (!githubToken) {
    throw new Error(
      "GITHUB_TOKEN environment variable is required. Please set it in your Kubernetes Secret."
    );
  }

  console.log("Using provided GITHUB_TOKEN for authentication");
  return githubToken;
}
