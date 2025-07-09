#!/usr/bin/env bun
/**
 * Kubernetes Job Runner for Agentic Coding System
 * 
 * Triggers Claude Code execution using our pre-configured claude-job.yaml
 * Creates ConfigMaps with prompt/config and applies the Job manifest
 */

import { spawn } from "child_process";
import type { ParsedGitHubContext } from "../github/context";

export interface BranchInfo {
  baseBranch: string;
  claudeBranch?: string;
  currentBranch: string;
}

export interface KubernetesJobParams {
  promptFile: string;
  mcpConfig: string;
  repository: {
    owner: string;
    repo: string;
    clone_url?: string;
  };
  githubToken: string;
  commentId: string;
  branchInfo: BranchInfo;
  context: ParsedGitHubContext;
}

export async function submitKubernetesJob(params: KubernetesJobParams): Promise<string> {
  const {
    promptFile,
    mcpConfig,
    repository,
    githubToken,
    commentId,
    branchInfo,
    context
  } = params;

  // Generate unique job ID
  const timestamp = Date.now();
  const randomId = Math.random().toString(36).substr(2, 9);
  const jobId = `claude-${timestamp}-${randomId}`;
  
  console.log(`Creating Kubernetes job: ${jobId}`);

  try {
    // Step 1: Create ConfigMap with prompt and MCP config
    const configMapName = `claude-config-${jobId}`;
    await createConfigMap({
      name: configMapName,
      prompt: promptFile,
      mcpConfig: mcpConfig,
      repository: `${repository.owner}/${repository.repo}`,
      ref: branchInfo.claudeBranch || branchInfo.currentBranch,
      jobId: jobId,
      commentId: commentId,
      allowedTools: context.inputs.allowedTools || "",
      disallowedTools: context.inputs.disallowedTools || "",
      maxTurns: context.inputs.maxTurns || "",
      systemPrompt: context.inputs.systemPrompt || "",
      appendSystemPrompt: context.inputs.appendSystemPrompt || "",
      timeoutMinutes: context.inputs.timeoutMinutes || "30",
      fallbackModel: context.inputs.fallbackModel || ""
    });

    // Step 2: Create Secret with GitHub token (if not exists)
    await ensureGitHubTokenSecret(githubToken);

    // Step 3: Apply the Claude job with our generated name
    await applyClaudeJob(jobId, configMapName);

    console.log(`Successfully created Kubernetes job: ${jobId}`);
    return jobId;

  } catch (error) {
    console.error(`Failed to create Kubernetes job: ${error}`);
    throw new Error(`Kubernetes job creation failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Create ConfigMap containing all configuration for the Claude job
 */
async function createConfigMap(config: {
  name: string;
  prompt: string;
  mcpConfig: string;
  repository: string;
  ref: string;
  jobId: string;
  commentId: string;
  allowedTools: string;
  disallowedTools: string;
  maxTurns: string;
  systemPrompt: string;
  appendSystemPrompt: string;
  timeoutMinutes: string;
  fallbackModel: string;
}): Promise<void> {
  const configMapYaml = `apiVersion: v1
kind: ConfigMap
metadata:
  name: ${config.name}
  labels:
    app: claude-runner
    claude.ai/job-id: "${config.jobId}"
data:
  github_repository: "${config.repository}"
  github_ref: "${config.ref}"
  job_id: "${config.jobId}"
  comment_id: "${config.commentId}"
  prompt: |
${config.prompt.split('\n').map(line => '    ' + line).join('\n')}
  mcp_config: |
${config.mcpConfig.split('\n').map(line => '    ' + line).join('\n')}
  allowed_tools: "${config.allowedTools}"
  disallowed_tools: "${config.disallowedTools}"
  max_turns: "${config.maxTurns}"
  system_prompt: "${config.systemPrompt}"
  append_system_prompt: "${config.appendSystemPrompt}"
  timeout_minutes: "${config.timeoutMinutes}"
  fallback_model: "${config.fallbackModel}"
`;

  // Apply the ConfigMap
  await execKubectl(['apply', '-f', '-'], configMapYaml);
  console.log(`Created ConfigMap: ${config.name}`);
}

/**
 * Ensure GitHub token secret exists
 */
async function ensureGitHubTokenSecret(token: string): Promise<void> {
  try {
    // Check if secret already exists
    await execKubectl(['get', 'secret', 'claude-secrets']);
    console.log('Secret claude-secrets already exists');
  } catch {
    // Create secret if it doesn't exist
    console.log('Creating claude-secrets...');
    
    // Note: In production, this should be managed by infrastructure
    // For now, we'll skip creating it since it should already exist
    console.log('Warning: claude-secrets should be created by infrastructure');
  }
}

/**
 * Apply the Claude job manifest with generated name
 */
async function applyClaudeJob(jobId: string, configMapName: string): Promise<void> {
  // Read the claude-job.yaml template and modify it
  const jobYamlPath = "/Users/devin/dblitz/engine/infrastructure/apps/base/claude-job.yaml";
  const jobYaml = await Bun.file(jobYamlPath).text();
  
  // Replace the job name and configmap references
  const modifiedYaml = jobYaml
    .replace(/name: claude-job/g, `name: ${jobId}`)
    .replace(/name: claude-config/g, `name: ${configMapName}`);
  
  // Apply the modified job
  await execKubectl(['apply', '-f', '-'], modifiedYaml);
  console.log(`Applied Kubernetes Job: ${jobId}`);
}

/**
 * Execute kubectl command
 */
function execKubectl(args: string[], stdin?: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const kubectl = spawn('kubectl', args, {
      env: { ...process.env }
    });
    
    let stdout = '';
    let stderr = '';
    
    kubectl.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    kubectl.stderr.on('data', (data) => {
      stderr += data.toString();
    });
    
    if (stdin) {
      kubectl.stdin.write(stdin);
      kubectl.stdin.end();
    }
    
    kubectl.on('close', (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(`kubectl ${args.join(' ')} failed: ${stderr}`));
      }
    });
    
    kubectl.on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Get job status (for monitoring/debugging)
 */
export async function getKubernetesJobStatus(jobId: string): Promise<{
  status: string;
  phase?: string;
  conditions?: any[];
}> {
  try {
    const output = await execKubectl(['get', 'job', jobId, '-o', 'json']);
    const job = JSON.parse(output);
    
    const isComplete = job.status?.succeeded > 0;
    const isFailed = job.status?.failed > 0;
    
    return {
      status: isComplete ? 'Complete' : isFailed ? 'Failed' : 'Running',
      phase: job.status?.conditions?.[0]?.type,
      conditions: job.status?.conditions || []
    };
  } catch (error) {
    console.error(`Failed to get job status: ${error}`);
    throw error;
  }
}

/**
 * Get job logs (for debugging)
 */
export async function getKubernetesJobLogs(jobId: string): Promise<string> {
  try {
    // Get logs from the job's pods
    const logs = await execKubectl(['logs', `job/${jobId}`, '--tail=1000']);
    return logs;
  } catch (error) {
    console.error(`Failed to get job logs: ${error}`);
    return `Failed to fetch logs: ${error}`;
  }
}

/**
 * Clean up completed job and its ConfigMap
 */
export async function cleanupKubernetesJob(jobId: string): Promise<void> {
  try {
    // Delete the job
    await execKubectl(['delete', 'job', jobId, '--ignore-not-found=true']);
    
    // Delete the ConfigMap
    const configMapName = `claude-config-${jobId}`;
    await execKubectl(['delete', 'configmap', configMapName, '--ignore-not-found=true']);
    
    console.log(`Cleaned up job ${jobId} and its resources`);
  } catch (error) {
    console.error(`Failed to cleanup job: ${error}`);
  }
}