/**
 * GitHub Data Fetcher for Agentic Coding System
 * 
 * Fetches comprehensive GitHub data for Claude Code context.
 * Adapted from anthropics/claude-code-action.
 */

import type { OctokitInstance } from "../api/client";

export interface FetchGitHubDataParams {
  octokits: OctokitInstance;
  repository: string; // "owner/repo" format
  prNumber?: string;
  isPR: boolean;
  triggerUsername: string;
}

export interface GitHubData {
  repository: {
    owner: string;
    name: string;
    fullName: string;
    defaultBranch: string;
    description?: string;
    private: boolean;
    url: string;
  };
  pullRequest?: {
    number: number;
    title: string;
    body: string;
    state: string;
    user: {
      login: string;
      type: string;
    };
    head: {
      ref: string;
      sha: string;
      label: string;
    };
    base: {
      ref: string;
      sha: string;
      label: string;
    };
    draft: boolean;
    mergeable?: boolean;
    url: string;
    files?: Array<{
      filename: string;
      status: string;
      additions: number;
      deletions: number;
      patch?: string;
    }>;
  };
  issue?: {
    number: number;
    title: string;
    body: string;
    state: string;
    user: {
      login: string;
      type: string;
    };
    assignees: Array<{
      login: string;
    }>;
    labels: Array<{
      name: string;
      color: string;
    }>;
    url: string;
  };
  triggerUser: {
    login: string;
    type: string;
    name?: string;
    company?: string;
  };
}

/**
 * Fetch comprehensive GitHub data for the context
 */
export async function fetchGitHubData(params: FetchGitHubDataParams): Promise<GitHubData> {
  const { octokits, repository, prNumber, isPR, triggerUsername } = params;
  const [owner, repo] = repository.split("/");

  console.log(`Fetching GitHub data for ${repository}`);

  try {
    // Fetch repository data
    const repositoryData = await fetchRepositoryData(octokits, owner, repo);

    // Fetch trigger user data
    const triggerUser = await fetchUserData(octokits, triggerUsername);

    const githubData: GitHubData = {
      repository: repositoryData,
      triggerUser,
    };

    // Fetch issue or PR specific data
    if (isPR && prNumber) {
      githubData.pullRequest = await fetchPullRequestData(octokits, owner, repo, parseInt(prNumber));
    } else if (prNumber) {
      githubData.issue = await fetchIssueData(octokits, owner, repo, parseInt(prNumber));
    }

    console.log(`✓ Successfully fetched GitHub data`);
    return githubData;

  } catch (error) {
    console.error(`Failed to fetch GitHub data: ${error instanceof Error ? error.message : String(error)}`);
    throw new Error(`GitHub data fetch failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Fetch repository information
 */
async function fetchRepositoryData(
  octokits: OctokitInstance,
  owner: string,
  repo: string
): Promise<GitHubData["repository"]> {
  const { data: repository } = await octokits.rest.repos.get({
    owner,
    repo,
  });

  return {
    owner: repository.owner.login,
    name: repository.name,
    fullName: repository.full_name,
    defaultBranch: repository.default_branch,
    description: repository.description || undefined,
    private: repository.private,
    url: repository.html_url,
  };
}

/**
 * Fetch pull request data with files
 */
async function fetchPullRequestData(
  octokits: OctokitInstance,
  owner: string,
  repo: string,
  prNumber: number
): Promise<GitHubData["pullRequest"]> {
  // Fetch PR basic data
  const { data: pr } = await octokits.rest.pulls.get({
    owner,
    repo,
    pull_number: prNumber,
  });

  // Fetch PR files
  let files: GitHubData["pullRequest"]["files"] = [];
  try {
    const { data: prFiles } = await octokits.rest.pulls.listFiles({
      owner,
      repo,
      pull_number: prNumber,
    });

    files = prFiles.map(file => ({
      filename: file.filename,
      status: file.status,
      additions: file.additions,
      deletions: file.deletions,
      patch: file.patch,
    }));

  } catch (error) {
    console.warn(`Could not fetch PR files: ${error instanceof Error ? error.message : String(error)}`);
  }

  return {
    number: pr.number,
    title: pr.title,
    body: pr.body || "",
    state: pr.state,
    user: {
      login: pr.user.login,
      type: pr.user.type,
    },
    head: {
      ref: pr.head.ref,
      sha: pr.head.sha,
      label: pr.head.label,
    },
    base: {
      ref: pr.base.ref,
      sha: pr.base.sha,
      label: pr.base.label,
    },
    draft: pr.draft,
    mergeable: pr.mergeable || undefined,
    url: pr.html_url,
    files,
  };
}

/**
 * Fetch issue data
 */
async function fetchIssueData(
  octokits: OctokitInstance,
  owner: string,
  repo: string,
  issueNumber: number
): Promise<GitHubData["issue"]> {
  const { data: issue } = await octokits.rest.issues.get({
    owner,
    repo,
    issue_number: issueNumber,
  });

  return {
    number: issue.number,
    title: issue.title,
    body: issue.body || "",
    state: issue.state,
    user: {
      login: issue.user.login,
      type: issue.user.type,
    },
    assignees: issue.assignees.map(assignee => ({
      login: assignee.login,
    })),
    labels: issue.labels
      .filter((label): label is { name: string; color: string } => 
        typeof label === "object" && label !== null && "name" in label && "color" in label
      )
      .map(label => ({
        name: label.name,
        color: label.color,
      })),
    url: issue.html_url,
  };
}

/**
 * Fetch user information
 */
async function fetchUserData(
  octokits: OctokitInstance,
  username: string
): Promise<GitHubData["triggerUser"]> {
  try {
    const { data: user } = await octokits.rest.users.getByUsername({
      username,
    });

    return {
      login: user.login,
      type: user.type,
      name: user.name || undefined,
      company: user.company || undefined,
    };

  } catch (error) {
    console.warn(`Could not fetch user data for ${username}: ${error instanceof Error ? error.message : String(error)}`);
    
    // Return minimal user data
    return {
      login: username,
      type: "User",
    };
  }
}

/**
 * Fetch repository contents for additional context
 */
export async function fetchRepositoryContents(
  octokits: OctokitInstance,
  owner: string,
  repo: string,
  path: string = "",
  ref?: string
): Promise<Array<{ name: string; type: string; path: string; size?: number }>> {
  try {
    const params: any = {
      owner,
      repo,
      path,
    };

    if (ref) {
      params.ref = ref;
    }

    const { data: contents } = await octokits.rest.repos.getContent(params);

    if (Array.isArray(contents)) {
      return contents.map(item => ({
        name: item.name,
        type: item.type,
        path: item.path,
        size: item.size,
      }));
    }

    // Single file
    return [{
      name: contents.name,
      type: contents.type,
      path: contents.path,
      size: contents.size,
    }];

  } catch (error) {
    console.warn(`Could not fetch repository contents for ${path}: ${error instanceof Error ? error.message : String(error)}`);
    return [];
  }
}