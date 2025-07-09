#!/usr/bin/env bun
/**
 * Nomad MCP Server for Agentic Coding System
 * 
 * Provides Claude Code with tools to interact with our Nomad cluster.
 * Allows monitoring and management of jobs, allocations, and cluster state.
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

const server = new Server(
  {
    name: "nomad-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Available Nomad tools for Claude Code
const NOMAD_TOOLS: Tool[] = [
  {
    name: "nomad_job_status",
    description: "Get the status of a Nomad job",
    inputSchema: {
      type: "object",
      properties: {
        job_id: {
          type: "string",
          description: "Nomad job ID to check",
        }
      },
      required: ["job_id"],
    },
  },
  {
    name: "nomad_job_logs",
    description: "Get logs from a Nomad job allocation",
    inputSchema: {
      type: "object",
      properties: {
        job_id: {
          type: "string",
          description: "Nomad job ID",
        },
        task_name: {
          type: "string",
          description: "Task name within the job",
          default: "claude-code"
        },
        log_type: {
          type: "string",
          description: "Log type to retrieve",
          enum: ["stdout", "stderr", "both"],
          default: "both"
        }
      },
      required: ["job_id"],
    },
  },
  {
    name: "nomad_list_jobs",
    description: "List Nomad jobs with optional filtering",
    inputSchema: {
      type: "object",
      properties: {
        prefix: {
          type: "string",
          description: "Job ID prefix filter",
        },
        status: {
          type: "string", 
          description: "Job status filter (running, pending, dead)",
        },
        namespace: {
          type: "string",
          description: "Nomad namespace",
          default: "default"
        }
      },
    },
  },
  {
    name: "nomad_cluster_status",
    description: "Get overall Nomad cluster status and node information",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "nomad_job_allocations",
    description: "Get allocations for a specific job",
    inputSchema: {
      type: "object",
      properties: {
        job_id: {
          type: "string",
          description: "Nomad job ID",
        }
      },
      required: ["job_id"],
    },
  },
  {
    name: "nomad_stop_job",
    description: "Stop a running Nomad job",
    inputSchema: {
      type: "object",
      properties: {
        job_id: {
          type: "string",
          description: "Nomad job ID to stop",
        },
        purge: {
          type: "boolean",
          description: "Purge job from system",
          default: false
        }
      },
      required: ["job_id"],
    },
  }
];

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: NOMAD_TOOLS,
  };
});

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "nomad_job_status":
        return await handleJobStatus(args);
      case "nomad_job_logs":
        return await handleJobLogs(args);
      case "nomad_list_jobs":
        return await handleListJobs(args);
      case "nomad_cluster_status":
        return await handleClusterStatus(args);
      case "nomad_job_allocations":
        return await handleJobAllocations(args);
      case "nomad_stop_job":
        return await handleStopJob(args);
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

// Helper function to get Nomad endpoint
function getNomadEndpoint(): string {
  return process.env.NOMAD_ADDR || "http://localhost:4646";
}

// Helper function to make Nomad API requests
async function nomadApiRequest(path: string): Promise<any> {
  const endpoint = getNomadEndpoint();
  const response = await fetch(`${endpoint}${path}`, {
    headers: {
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Nomad API error: ${response.status} - ${await response.text()}`);
  }

  return await response.json();
}

// Tool implementations
async function handleJobStatus(args: any) {
  const { job_id } = args;
  
  const job = await nomadApiRequest(`/v1/job/${job_id}`);
  
  const statusInfo = {
    id: job.ID,
    name: job.Name,
    status: job.Status,
    type: job.Type,
    priority: job.Priority,
    datacenters: job.Datacenters,
    createTime: job.CreateTime,
    modifyTime: job.ModifyTime,
    summary: job.JobSummary
  };

  return {
    content: [
      {
        type: "text",
        text: `Job Status for ${job_id}:\n\n${JSON.stringify(statusInfo, null, 2)}`,
      },
    ],
  };
}

async function handleJobLogs(args: any) {
  const { job_id, task_name = "claude-code", log_type = "both" } = args;
  
  // Get allocations for the job
  const allocations = await nomadApiRequest(`/v1/job/${job_id}/allocations`);
  
  if (allocations.length === 0) {
    throw new Error(`No allocations found for job ${job_id}`);
  }

  const allocId = allocations[0].ID;
  let logs = "";

  if (log_type === "stdout" || log_type === "both") {
    try {
      const stdoutResponse = await fetch(`${getNomadEndpoint()}/v1/client/fs/logs/${allocId}?task=${task_name}&type=stdout&plain=true`);
      if (stdoutResponse.ok) {
        const stdout = await stdoutResponse.text();
        logs += `=== STDOUT ===\n${stdout}\n\n`;
      }
    } catch (error) {
      logs += `=== STDOUT ===\nError fetching stdout: ${error}\n\n`;
    }
  }

  if (log_type === "stderr" || log_type === "both") {
    try {
      const stderrResponse = await fetch(`${getNomadEndpoint()}/v1/client/fs/logs/${allocId}?task=${task_name}&type=stderr&plain=true`);
      if (stderrResponse.ok) {
        const stderr = await stderrResponse.text();
        logs += `=== STDERR ===\n${stderr}\n\n`;
      }
    } catch (error) {
      logs += `=== STDERR ===\nError fetching stderr: ${error}\n\n`;
    }
  }

  return {
    content: [
      {
        type: "text",
        text: `Logs for job ${job_id} (task: ${task_name}):\n\n${logs}`,
      },
    ],
  };
}

async function handleListJobs(args: any) {
  const { prefix, status, namespace = "default" } = args;
  
  let path = `/v1/jobs?namespace=${namespace}`;
  if (prefix) path += `&prefix=${prefix}`;
  
  const jobs = await nomadApiRequest(path);
  
  let filteredJobs = jobs;
  if (status) {
    filteredJobs = jobs.filter((job: any) => job.Status === status);
  }

  const jobSummary = filteredJobs.map((job: any) => ({
    id: job.ID,
    name: job.Name,
    status: job.Status,
    type: job.Type,
    createTime: job.CreateTime,
    modifyTime: job.ModifyTime
  }));

  return {
    content: [
      {
        type: "text",
        text: `Nomad Jobs (${filteredJobs.length} total):\n\n${JSON.stringify(jobSummary, null, 2)}`,
      },
    ],
  };
}

async function handleClusterStatus(args: any) {
  // Get cluster leader
  const leader = await nomadApiRequest("/v1/status/leader");
  
  // Get cluster nodes
  const nodes = await nomadApiRequest("/v1/nodes");
  
  // Get cluster stats
  const nodeDetails = await Promise.all(
    nodes.slice(0, 5).map(async (node: any) => {
      try {
        const nodeInfo = await nomadApiRequest(`/v1/node/${node.ID}`);
        return {
          id: node.ID,
          name: node.Name,
          status: node.Status,
          datacenter: node.Datacenter,
          drain: node.Drain,
          schedulingEligibility: node.SchedulingEligibility,
          resources: nodeInfo.Resources
        };
      } catch (error) {
        return {
          id: node.ID,
          name: node.Name,
          status: node.Status,
          error: "Failed to fetch details"
        };
      }
    })
  );

  const clusterInfo = {
    leader,
    nodeCount: nodes.length,
    nodes: nodeDetails
  };

  return {
    content: [
      {
        type: "text",
        text: `Nomad Cluster Status:\n\n${JSON.stringify(clusterInfo, null, 2)}`,
      },
    ],
  };
}

async function handleJobAllocations(args: any) {
  const { job_id } = args;
  
  const allocations = await nomadApiRequest(`/v1/job/${job_id}/allocations`);
  
  const allocInfo = allocations.map((alloc: any) => ({
    id: alloc.ID,
    nodeId: alloc.NodeID,
    jobId: alloc.JobID,
    taskGroup: alloc.TaskGroup,
    clientStatus: alloc.ClientStatus,
    desiredStatus: alloc.DesiredStatus,
    createTime: alloc.CreateTime,
    modifyTime: alloc.ModifyTime
  }));

  return {
    content: [
      {
        type: "text",
        text: `Allocations for job ${job_id}:\n\n${JSON.stringify(allocInfo, null, 2)}`,
      },
    ],
  };
}

async function handleStopJob(args: any) {
  const { job_id, purge = false } = args;
  
  const endpoint = getNomadEndpoint();
  const purgeParam = purge ? "?purge=true" : "";
  
  const response = await fetch(`${endpoint}/v1/job/${job_id}${purgeParam}`, {
    method: "DELETE",
    headers: {
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to stop job: ${response.status} - ${await response.text()}`);
  }

  const result = await response.json();

  return {
    content: [
      {
        type: "text",
        text: `Job ${job_id} stop request submitted:\n\n${JSON.stringify(result, null, 2)}`,
      },
    ],
  };
}

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Nomad MCP Server running on stdio");
}

if (import.meta.main) {
  main().catch(console.error);
}