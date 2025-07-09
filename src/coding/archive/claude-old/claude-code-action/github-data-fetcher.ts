#!/usr/bin/env bun
/**
 * github-data-fetcher.ts - Retrieves GitHub data
 * 
 * Exactly matches Claude Code Action's GitHub data fetching logic.
 * Fetches relevant GitHub context for Claude's analysis.
 */

import type { ParsedGitHubContext } from "../github/context";

export interface GitHubDataOptions {
  github_token: string;
  include_files?: boolean;
  include_diff?: boolean;
  include_history?: boolean;
  max_files?: number;
}

export interface GitHubData {
  files?: Array<{
    filename: string;
    status: 'added' | 'modified' | 'removed';
    additions?: number;
    deletions?: number;
    changes?: number;
    patch?: string;
  }>;
  diff?: string;
  commits?: Array<{
    sha: string;
    message: string;
    author: {
      name: string;
      email: string;
    };
    url: string;
  }>;
  repository_files?: Array<{
    path: string;
    content?: string;
  }>;
}

export async function fetchGitHubData(
  context: ParsedGitHubContext,
  options: GitHubDataOptions
): Promise<GitHubData> {
  const {
    github_token,
    include_files = false,
    include_diff = false,
    include_history = false,
    max_files = 10
  } = options;

  const result: GitHubData = {};

  // Only fetch additional data for pull requests
  if (context.entityType !== 'pull_request' || !context.pullRequest) {
    return result;
  }

  const baseUrl = 'https://api.github.com';
  const repoPath = `repos/${context.repository?.full_name}`;
  const prNumber = context.pullRequest.number;

  const headers = {
    'Authorization': `Bearer ${github_token}`,
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'Claude-Code-Action'
  };

  try {
    // Fetch PR files if requested
    if (include_files) {
      const filesResponse = await fetch(
        `${baseUrl}/${repoPath}/pulls/${prNumber}/files?per_page=${max_files}`,
        { headers }
      );
      
      if (filesResponse.ok) {
        const files = await filesResponse.json();
        result.files = files.map((file: any) => ({
          filename: file.filename,
          status: file.status,
          additions: file.additions,
          deletions: file.deletions,
          changes: file.changes,
          patch: file.patch
        }));
      }
    }

    // Fetch PR diff if requested
    if (include_diff) {
      const diffResponse = await fetch(
        `${baseUrl}/${repoPath}/pulls/${prNumber}`,
        {
          headers: {
            ...headers,
            'Accept': 'application/vnd.github.v3.diff'
          }
        }
      );
      
      if (diffResponse.ok) {
        result.diff = await diffResponse.text();
      }
    }

    // Fetch PR commits if requested
    if (include_history) {
      const commitsResponse = await fetch(
        `${baseUrl}/${repoPath}/pulls/${prNumber}/commits`,
        { headers }
      );
      
      if (commitsResponse.ok) {
        const commits = await commitsResponse.json();
        result.commits = commits.map((commit: any) => ({
          sha: commit.sha,
          message: commit.commit.message,
          author: {
            name: commit.commit.author.name,
            email: commit.commit.author.email
          },
          url: commit.html_url
        }));
      }
    }

  } catch (error) {
    console.error('Failed to fetch GitHub data:', error);
    // Return partial data rather than failing completely
  }

  return result;
}

export async function fetchFileContent(
  repoFullName: string,
  filePath: string,
  ref: string,
  github_token: string
): Promise<string | null> {
  try {
    const baseUrl = 'https://api.github.com';
    const response = await fetch(
      `${baseUrl}/repos/${repoFullName}/contents/${filePath}?ref=${ref}`,
      {
        headers: {
          'Authorization': `Bearer ${github_token}`,
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Claude-Code-Action'
        }
      }
    );

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    
    // Handle file content (base64 encoded)
    if (data.content && data.encoding === 'base64') {
      return Buffer.from(data.content, 'base64').toString('utf-8');
    }

    return null;
  } catch (error) {
    console.error(`Failed to fetch file content for ${filePath}:`, error);
    return null;
  }
}