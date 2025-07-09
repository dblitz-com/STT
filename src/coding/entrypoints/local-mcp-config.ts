// Local MCP Config - Exact copy of install-mcp-server.ts but for local workflow
import * as path from "path";

type PrepareLocalMcpConfigParams = {
  repoDir: string;
  branch: string;
  additionalMcpConfig?: string;
};

export async function prepareLocalMcpConfig(
  params: PrepareLocalMcpConfigParams,
): Promise<string> {
  const {
    repoDir,
    branch,
    additionalMcpConfig,
  } = params;
  try {
    const baseMcpConfig: { mcpServers: Record<string, unknown> } = {
      mcpServers: {
        local_git_ops: {
          command: "bun",
          args: [
            "run",
            path.join(__dirname, "local-git-ops-server.ts"),
          ],
          env: {
            REPO_DIR: repoDir,
            BRANCH_NAME: branch,
          },
        },
        github_file_ops: {
          command: "bun",
          args: [
            "run",
            path.join(__dirname, "..", "mcp", "github-operations-server.ts"),
          ],
          env: {
            GITHUB_TOKEN: process.env.GITHUB_TOKEN || "",
          },
        },
      },
    };

    // Merge with additional MCP config if provided
    if (additionalMcpConfig && additionalMcpConfig.trim()) {
      try {
        const additionalConfig = JSON.parse(additionalMcpConfig);

        // Validate that parsed JSON is an object
        if (typeof additionalConfig !== "object" || additionalConfig === null) {
          throw new Error("MCP config must be a valid JSON object");
        }

        console.log(
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
        console.warn(
          `Failed to parse additional MCP config: ${parseError}. Using base config only.`,
        );
      }
    }

    return JSON.stringify(baseMcpConfig, null, 2);
  } catch (error) {
    console.error(`Install MCP server failed with error: ${error}`);
    process.exit(1);
  }
}