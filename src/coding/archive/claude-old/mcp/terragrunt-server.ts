#!/usr/bin/env bun
/**
 * Terragrunt MCP Server for Agentic Coding System
 * 
 * Provides Claude Code with tools to interact with our Terragrunt infrastructure.
 * Follows MCP (Model Context Protocol) specification.
 * 
 * Related to GitHub Issue #15: Implement Agentic Coding System with Claude Code SDK Python Runtime
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "child_process";
import { existsSync, readFileSync } from "fs";
import path from "path";

const server = new Server(
  {
    name: "terragrunt-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Available Terragrunt tools for Claude Code
const TERRAGRUNT_TOOLS: Tool[] = [
  {
    name: "terragrunt_plan",
    description: "Run terragrunt plan in a specific module to preview infrastructure changes",
    inputSchema: {
      type: "object",
      properties: {
        module_path: {
          type: "string",
          description: "Path to the Terragrunt module (relative to infrastructure/terragrunt/)",
        },
        env: {
          type: "string", 
          description: "Environment (development, staging, production)",
          default: "development"
        }
      },
      required: ["module_path"],
    },
  },
  {
    name: "terragrunt_apply",
    description: "Apply Terragrunt configuration for a module (use with caution)",
    inputSchema: {
      type: "object",
      properties: {
        module_path: {
          type: "string",
          description: "Path to the Terragrunt module (relative to infrastructure/terragrunt/)",
        },
        env: {
          type: "string",
          description: "Environment (development, staging, production)", 
          default: "development"
        },
        auto_approve: {
          type: "boolean",
          description: "Skip interactive approval",
          default: false
        }
      },
      required: ["module_path"],
    },
  },
  {
    name: "terragrunt_show",
    description: "Show current state of Terragrunt infrastructure",
    inputSchema: {
      type: "object", 
      properties: {
        module_path: {
          type: "string",
          description: "Path to the Terragrunt module",
        },
        env: {
          type: "string",
          description: "Environment",
          default: "development"
        }
      },
      required: ["module_path"],
    },
  },
  {
    name: "terragrunt_output",
    description: "Get outputs from a Terragrunt module",
    inputSchema: {
      type: "object",
      properties: {
        module_path: {
          type: "string", 
          description: "Path to the Terragrunt module",
        },
        env: {
          type: "string",
          description: "Environment",
          default: "development"
        },
        output_name: {
          type: "string",
          description: "Specific output to retrieve (optional)",
        }
      },
      required: ["module_path"],
    },
  },
  {
    name: "terragrunt_validate",
    description: "Validate Terragrunt configuration files",
    inputSchema: {
      type: "object",
      properties: {
        module_path: {
          type: "string",
          description: "Path to the Terragrunt module to validate",
        }
      },
      required: ["module_path"],
    },
  },
  {
    name: "list_terragrunt_modules",
    description: "List available Terragrunt modules in the infrastructure",
    inputSchema: {
      type: "object",
      properties: {
        env: {
          type: "string", 
          description: "Environment filter (optional)",
        }
      },
    },
  }
];

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: TERRAGRUNT_TOOLS,
  };
});

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "terragrunt_plan":
        return await handleTerragruntPlan(args);
      case "terragrunt_apply": 
        return await handleTerragruntApply(args);
      case "terragrunt_show":
        return await handleTerragruntShow(args);
      case "terragrunt_output":
        return await handleTerragruntOutput(args);
      case "terragrunt_validate":
        return await handleTerragruntValidate(args);
      case "list_terragrunt_modules":
        return await handleListModules(args);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error executing ${name}: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
    };
  }
});

// Tool implementations
async function handleTerragruntPlan(args: any) {
  const { module_path, env = "development" } = args;
  const fullPath = path.join("infrastructure/terragrunt", env, module_path);
  
  if (!existsSync(fullPath)) {
    throw new Error(`Module path does not exist: ${fullPath}`);
  }

  const command = `cd ${fullPath} && terragrunt plan`;
  const output = execSync(command, { encoding: "utf-8", timeout: 300000 }); // 5 min timeout

  return {
    content: [
      {
        type: "text",
        text: `Terragrunt plan for ${module_path} (${env}):\n\n${output}`,
      },
    ],
  };
}

async function handleTerragruntApply(args: any) {
  const { module_path, env = "development", auto_approve = false } = args;
  const fullPath = path.join("infrastructure/terragrunt", env, module_path);
  
  if (!existsSync(fullPath)) {
    throw new Error(`Module path does not exist: ${fullPath}`);
  }

  const autoApproveFlag = auto_approve ? "-auto-approve" : "";
  const command = `cd ${fullPath} && terragrunt apply ${autoApproveFlag}`;
  
  // Longer timeout for apply operations
  const output = execSync(command, { encoding: "utf-8", timeout: 600000 }); // 10 min timeout

  return {
    content: [
      {
        type: "text", 
        text: `Terragrunt apply for ${module_path} (${env}):\n\n${output}`,
      },
    ],
  };
}

async function handleTerragruntShow(args: any) {
  const { module_path, env = "development" } = args;
  const fullPath = path.join("infrastructure/terragrunt", env, module_path);
  
  if (!existsSync(fullPath)) {
    throw new Error(`Module path does not exist: ${fullPath}`);
  }

  const command = `cd ${fullPath} && terragrunt show`;
  const output = execSync(command, { encoding: "utf-8", timeout: 120000 });

  return {
    content: [
      {
        type: "text",
        text: `Terragrunt state for ${module_path} (${env}):\n\n${output}`,
      },
    ],
  };
}

async function handleTerragruntOutput(args: any) {
  const { module_path, env = "development", output_name } = args;
  const fullPath = path.join("infrastructure/terragrunt", env, module_path);
  
  if (!existsSync(fullPath)) {
    throw new Error(`Module path does not exist: ${fullPath}`);
  }

  const outputFlag = output_name ? output_name : "";
  const command = `cd ${fullPath} && terragrunt output ${outputFlag}`;
  const output = execSync(command, { encoding: "utf-8", timeout: 60000 });

  return {
    content: [
      {
        type: "text",
        text: `Terragrunt outputs for ${module_path} (${env}):\n\n${output}`,
      },
    ],
  };
}

async function handleTerragruntValidate(args: any) {
  const { module_path } = args;
  const fullPath = path.join("infrastructure/terragrunt", module_path);
  
  if (!existsSync(fullPath)) {
    throw new Error(`Module path does not exist: ${fullPath}`);
  }

  const command = `cd ${fullPath} && terragrunt validate`;
  const output = execSync(command, { encoding: "utf-8", timeout: 60000 });

  return {
    content: [
      {
        type: "text",
        text: `Terragrunt validation for ${module_path}:\n\n${output}`,
      },
    ],
  };
}

async function handleListModules(args: any) {
  const { env } = args;
  const basePath = "infrastructure/terragrunt";
  const searchPath = env ? path.join(basePath, env) : basePath;
  
  if (!existsSync(searchPath)) {
    throw new Error(`Path does not exist: ${searchPath}`);
  }

  // Find all terragrunt.hcl files to identify modules
  const command = `find ${searchPath} -name "terragrunt.hcl" -type f`;
  const output = execSync(command, { encoding: "utf-8" });
  
  const modules = output
    .split("\n")
    .filter(line => line.trim())
    .map(line => line.replace(searchPath + "/", "").replace("/terragrunt.hcl", ""));

  return {
    content: [
      {
        type: "text",
        text: `Available Terragrunt modules${env ? ` in ${env}` : ""}:\n\n${modules.join("\n")}`,
      },
    ],
  };
}

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Terragrunt MCP Server running on stdio");
}

if (import.meta.main) {
  main().catch(console.error);
}