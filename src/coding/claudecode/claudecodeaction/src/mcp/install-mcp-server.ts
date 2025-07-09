import { GITHUB_API_URL } from "../github/api/config";
import type { ParsedGitHubContext } from "../github/context";
import { Octokit } from "@octokit/rest";

import { core } from "../../../../utils/kubernetes-core";

type PrepareConfigParams = {
  githubToken: string;
  owner: string;
  repo: string;
  branch: string;
  additionalMcpConfig?: string;
  claudeCommentId?: string;
  allowedTools: string[];
  context: ParsedGitHubContext;
};


export async function prepareMcpConfig(
  params: PrepareConfigParams,
): Promise<string> {
  const {
    githubToken,
    owner,
    repo,
    branch,
    additionalMcpConfig,
    claudeCommentId,
    allowedTools,
    context,
  } = params;
  try {
    const allowedToolsList = allowedTools || [];

    const hasGitHubMcpTools = allowedToolsList.some((tool) =>
      tool.startsWith("mcp__github__"),
    );

    // Determine paths
    const actionPath = process.env.GITHUB_ACTION_PATH || "/workspace/src/coding/claudecode/claudecodeaction";
    const repoDir = process.env.GITHUB_WORKSPACE || process.cwd();

    const baseMcpConfig: { mcpServers: Record<string, unknown> } = {
      mcpServers: {
        github_file_ops: {
          command: "bun",
          args: [
            "run",
            `${actionPath}/src/mcp/github-file-ops-server.ts`,
          ],
          env: {
            GITHUB_TOKEN: githubToken,
            REPO_OWNER: owner,
            REPO_NAME: repo,
            BRANCH_NAME: branch,
            REPO_DIR: repoDir,
            ...(claudeCommentId && { CLAUDE_COMMENT_ID: claudeCommentId }),
            GITHUB_EVENT_NAME: process.env.GITHUB_EVENT_NAME || "",
            IS_PR: process.env.IS_PR || "false",
            GITHUB_API_URL: GITHUB_API_URL,
          },
        },
      },
    };

    // Add CI server if we're in a PR context AND actions:read permission is granted
    const hasActionsReadPermission = context.inputs.additionalPermissions.has("actions") &&
      context.inputs.additionalPermissions.get("actions") === "read";

    if (context.isPR && hasActionsReadPermission) {
      const actionsToken = process.env.ACTIONS_TOKEN;
      
      // Always warn about permission requirements when setting up github_ci server
      core.warning(
        "The github_ci MCP server requires 'actions: read' permission to function properly"
      );

      baseMcpConfig.mcpServers.github_ci = {
        command: "bun",
        args: [
          "run",
          `${actionPath}/src/mcp/github-actions-server.ts`,
        ],
        env: {
          GITHUB_TOKEN: actionsToken || githubToken,
          REPO_OWNER: owner,
          REPO_NAME: repo,
          PR_NUMBER: context.entityNumber.toString(),
          RUNNER_TEMP: "/tmp",
        },
      };
    }

    if (hasGitHubMcpTools) {
      baseMcpConfig.mcpServers.github = {
        command: "docker",
        args: [
          "run",
          "-i",
          "--rm",
          "-e",
          "GITHUB_PERSONAL_ACCESS_TOKEN",
          "ghcr.io/github/github-mcp-server:sha-721fd3e", // https://github.com/github/github-mcp-server/releases/tag/v0.6.0
        ],
        env: {
          GITHUB_PERSONAL_ACCESS_TOKEN: githubToken,
        },
      };
    }

    // Merge with additional MCP config if provided
    if (additionalMcpConfig && additionalMcpConfig.trim()) {
      try {
        const additionalConfig = JSON.parse(additionalMcpConfig);

        // Validate that parsed JSON is an object
        if (typeof additionalConfig !== "object" || additionalConfig === null) {
          throw new Error("MCP config must be a valid JSON object");
        }

        core.info(
          "Merging additional MCP server configuration with built-in servers",
        );

        // Merge configurations with user config overriding built-in servers
        const mergedConfig = {
          ...baseMcpConfig,
          ...additionalConfig,
          mcpServers: {
            ...baseMcpConfig.mcpServers,
            ...additionalConfig.mcpServers,
          },
        };

        return JSON.stringify(mergedConfig, null, 2);
      } catch (parseError) {
        core.warning(
          `Failed to parse additional MCP config: ${parseError}. Using base config only.`,
        );
      }
    }

    return JSON.stringify(baseMcpConfig, null, 2);
  } catch (error) {
    core.setFailed(`Install MCP server failed with error: ${error}`);
    process.exit(1);
  }
}
