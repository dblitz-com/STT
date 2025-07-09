/**
 * MCP Server Installation and Configuration for Agentic Coding System
 * 
 * Prepares MCP configurations with our custom servers for Claude Code.
 * Adapted from anthropics/claude-code-action.
 */

import type { ParsedGitHubContext } from "../github/context";

export interface McpConfigParams {
  githubToken: string;
  owner: string;
  repo: string;
  branch: string;
  additionalMcpConfig: string;
  claudeCommentId: string;
  allowedTools?: string[];
  context: ParsedGitHubContext;
}

/**
 * Prepare MCP configuration for Claude Code execution
 */
export async function prepareMcpConfig(params: McpConfigParams): Promise<string> {
  const {
    githubToken,
    owner,
    repo,
    branch,
    additionalMcpConfig,
    claudeCommentId,
    allowedTools = [],
    context
  } = params;

  console.log("Preparing MCP configuration with custom servers");

  // Base MCP configuration with our custom servers
  const mcpConfig = {
    mcpServers: {
      // GitHub integration server (for repository operations)
      github: {
        command: "npx",
        args: [
          "-y",
          "@modelcontextprotocol/server-github",
          `${owner}/${repo}`
        ],
        env: {
          GITHUB_PERSONAL_ACCESS_TOKEN: githubToken
        }
      },

      // Our custom Terragrunt server
      terragrunt: {
        command: "bun",
        args: ["/workspace/src/coding/mcp/terragrunt-server.ts"],
        env: {
          TERRAGRUNT_CONFIG_PATH: "/infrastructure/terragrunt",
          AWS_PROFILE: process.env.AWS_PROFILE || "default",
          AWS_REGION: process.env.AWS_REGION || "us-east-1"
        }
      },

      // Our custom Nomad server
      nomad: {
        command: "bun", 
        args: ["/workspace/src/coding/mcp/nomad-server.ts"],
        env: {
          NOMAD_ADDR: process.env.NOMAD_ADDR || "http://localhost:4646",
          NOMAD_TOKEN: process.env.NOMAD_TOKEN || ""
        }
      },

      // File system operations
      filesystem: {
        command: "npx",
        args: [
          "-y",
          "@modelcontextprotocol/server-filesystem",
          "/workspace"
        ]
      },

      // Search functionality
      brave_search: {
        command: "npx",
        args: [
          "-y", 
          "@modelcontextprotocol/server-brave-search"
        ],
        env: {
          BRAVE_API_KEY: process.env.BRAVE_API_KEY || ""
        }
      }
    }
  };

  // Add conditional servers based on allowed tools
  if (allowedTools.includes("git") || allowedTools.length === 0) {
    mcpConfig.mcpServers.git = {
      command: "npx",
      args: [
        "-y",
        "@modelcontextprotocol/server-git",
        "--repository",
        "/workspace/repo"
      ]
    };
  }

  if (allowedTools.includes("postgres") || allowedTools.includes("database")) {
    mcpConfig.mcpServers.postgres = {
      command: "npx", 
      args: [
        "-y",
        "@modelcontextprotocol/server-postgres"
      ],
      env: {
        POSTGRES_CONNECTION_STRING: process.env.POSTGRES_CONNECTION_STRING || ""
      }
    };
  }

  if (allowedTools.includes("slack") && process.env.SLACK_BOT_TOKEN) {
    mcpConfig.mcpServers.slack = {
      command: "npx",
      args: [
        "-y", 
        "@modelcontextprotocol/server-slack"
      ],
      env: {
        SLACK_BOT_TOKEN: process.env.SLACK_BOT_TOKEN
      }
    };
  }

  // Parse and merge additional MCP config if provided
  if (additionalMcpConfig) {
    try {
      const additionalConfig = JSON.parse(additionalMcpConfig);
      if (additionalConfig.mcpServers) {
        Object.assign(mcpConfig.mcpServers, additionalConfig.mcpServers);
      }
    } catch (error) {
      console.warn(`Failed to parse additional MCP config: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // Add context-specific environment variables
  Object.values(mcpConfig.mcpServers).forEach(server => {
    if (server.env) {
      server.env.CLAUDE_COMMENT_ID = claudeCommentId;
      server.env.REPOSITORY_OWNER = owner;
      server.env.REPOSITORY_NAME = repo;
      server.env.WORKING_BRANCH = branch;
      server.env.GITHUB_TOKEN = githubToken;
      server.env.ISSUE_NUMBER = context.entityNumber?.toString() || "";
      server.env.IS_PR = context.isPR ? "true" : "false";
    }
  });

  console.log(`✓ Prepared MCP configuration with ${Object.keys(mcpConfig.mcpServers).length} servers`);
  
  return JSON.stringify(mcpConfig, null, 2);
}

/**
 * Get default allowed tools for Claude Code
 */
export function getDefaultAllowedTools(): string[] {
  return [
    "git",
    "filesystem", 
    "github",
    "terragrunt",
    "nomad",
    "brave_search"
  ];
}

/**
 * Validate MCP configuration
 */
export function validateMcpConfig(mcpConfigJson: string): boolean {
  try {
    const config = JSON.parse(mcpConfigJson);
    
    if (!config.mcpServers) {
      console.error("MCP config missing mcpServers section");
      return false;
    }

    // Check that we have at least basic servers
    const requiredServers = ["filesystem", "github"];
    for (const server of requiredServers) {
      if (!config.mcpServers[server]) {
        console.error(`MCP config missing required server: ${server}`);
        return false;
      }
    }

    console.log("✓ MCP configuration validation passed");
    return true;

  } catch (error) {
    console.error(`MCP config validation failed: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

/**
 * Get MCP server list for logging
 */
export function getMcpServerList(mcpConfigJson: string): string[] {
  try {
    const config = JSON.parse(mcpConfigJson);
    return Object.keys(config.mcpServers || {});
  } catch (error) {
    console.error(`Failed to parse MCP config: ${error instanceof Error ? error.message : String(error)}`);
    return [];
  }
}