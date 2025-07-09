#!/usr/bin/env bun
/**
 * ⚠️  OPTION B - CUSTOM KUBERNETES IMPLEMENTATION ⚠️
 * 
 * DO NOT USE THIS UNLESS FIXING GITHUB ACTIONS RUNNER ISSUES!
 * 
 * PREFERRED SOLUTION: Use GitHub Actions self-hosted runners (Option A)
 * See refs/claude-code-action and refs/claude-code-base-action for official implementation
 * 
 * This webhook handler creates Kubernetes Jobs instead of triggering GitHub Actions.
 * This approach lacks proper GitHub Actions context and comment formatting.
 * 
 * Webhook Handler for Claude Code Actions
 * 
 * This handler receives GitHub webhooks and creates Kubernetes Jobs
 * to run Claude Code Action in response to PR comments and issues.
 */

import { createHash } from "crypto";

interface WebhookPayload {
  action?: string;
  issue?: any;
  pull_request?: any;
  comment?: any;
  repository: any;
  sender: any;
}

interface KubernetesClient {
  createConfigMap(name: string, namespace: string, data: Record<string, string>): Promise<void>;
  createJob(name: string, namespace: string, spec: any): Promise<void>;
}

// Simple Kubernetes client using kubectl
class KubectlClient implements KubernetesClient {
  async createConfigMap(name: string, namespace: string, data: Record<string, string>): Promise<void> {
    const configMap = {
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: { name, namespace },
      data
    };
    
    const yaml = JSON.stringify(configMap);
    const proc = Bun.spawn(["kubectl", "apply", "-f", "-"], {
      stdin: new TextEncoder().encode(yaml)
    });
    
    await proc.exited;
    if (proc.exitCode !== 0) {
      throw new Error(`Failed to create ConfigMap: ${name}`);
    }
  }
  
  async createJob(name: string, namespace: string, spec: any): Promise<void> {
    const job = {
      apiVersion: "batch/v1",
      kind: "Job",
      metadata: { name, namespace },
      spec
    };
    
    const yaml = JSON.stringify(job);
    const proc = Bun.spawn(["kubectl", "apply", "-f", "-"], {
      stdin: new TextEncoder().encode(yaml)
    });
    
    await proc.exited;
    if (proc.exitCode !== 0) {
      throw new Error(`Failed to create Job: ${name}`);
    }
  }
}

export async function handleClaudeWebhook(payload: WebhookPayload): Promise<void> {
  console.log("🔔 Received webhook for Claude Code Action");
  
  // Check if this is a comment that should trigger Claude
  const isIssueComment = payload.action === "created" && payload.comment && payload.issue;
  const isPRComment = payload.action === "created" && payload.comment && payload.pull_request;
  
  if (!isIssueComment && !isPRComment) {
    console.log("ℹ️ Not a comment event, ignoring");
    return;
  }
  
  const comment = payload.comment;
  const triggerPhrase = process.env.TRIGGER_PHRASE || "@claude";
  
  if (!comment.body.includes(triggerPhrase)) {
    console.log(`ℹ️ Comment doesn't contain trigger phrase: ${triggerPhrase}`);
    return;
  }
  
  console.log("✅ Trigger phrase found, creating Claude job...");
  
  // Generate unique job name
  const timestamp = Date.now();
  const hash = createHash('md5').update(`${comment.id}-${timestamp}`).digest('hex').substring(0, 8);
  const jobName = `claude-job-${hash}`;
  const configMapName = `claude-config-${hash}`;
  
  // Prepare data for the job
  const entity = payload.issue || payload.pull_request;
  const eventName = payload.issue ? "issues" : "pull_request";
  
  // Create ConfigMap with all necessary data
  const configMapData = {
    job_id: jobName,
    comment_id: comment.id.toString(),
    github_repository: payload.repository.full_name,
    github_ref: entity.head?.ref || payload.repository.default_branch,
    github_event_name: eventName,
    github_event_payload: JSON.stringify(payload),
    allowed_tools: process.env.ALLOWED_TOOLS || "Edit,MultiEdit,Glob,Grep,LS,Read,Write,mcp__github_file_ops__commit_files,mcp__github_file_ops__delete_files,mcp__github_file_ops__update_claude_comment",
    disallowed_tools: process.env.DISALLOWED_TOOLS || "",
    max_turns: process.env.MAX_TURNS || "10",
    timeout_minutes: process.env.TIMEOUT_MINUTES || "30",
    system_prompt: process.env.SYSTEM_PROMPT || "",
    append_system_prompt: process.env.APPEND_SYSTEM_PROMPT || "",
    fallback_model: process.env.FALLBACK_MODEL || "",
    prompt: comment.body,
    mcp_config: JSON.stringify({
      mcpServers: {
        github_file_ops: {
          command: "bun",
          args: ["run", "/app/src/coding/claudecode/claudecodeaction/src/mcp/github-file-ops-server.ts"],
          env: {
            GITHUB_TOKEN: "${GITHUB_TOKEN}",
            REPO_OWNER: payload.repository.owner.login,
            REPO_NAME: payload.repository.name,
            BRANCH_NAME: "${BRANCH_NAME}",
            REPO_DIR: "/workspace",
            CLAUDE_COMMENT_ID: comment.id.toString(),
            GITHUB_EVENT_NAME: eventName,
            IS_PR: isPRComment ? "true" : "false",
            GITHUB_API_URL: process.env.GITHUB_API_URL || "https://api.github.com"
          }
        }
      }
    })
  };
  
  // Create Kubernetes resources
  const k8s = new KubectlClient();
  const namespace = process.env.KUBERNETES_NAMESPACE || "default";
  
  try {
    // Create ConfigMap
    await k8s.createConfigMap(configMapName, namespace, configMapData);
    console.log(`✅ Created ConfigMap: ${configMapName}`);
    
    // Create Job using the template
    const jobSpec = {
      template: {
        metadata: {
          labels: {
            app: "claude-runner",
            "claude-job-id": jobName
          }
        },
        spec: {
          serviceAccountName: "claude-runner",
          restartPolicy: "Never",
          initContainers: [{
            name: "git-clone",
            image: "alpine/git:latest",
            command: ["sh", "-c", `
              git config --global credential.helper store
              echo "https://x-access-token:\${GITHUB_TOKEN}@github.com" > ~/.git-credentials
              git clone https://github.com/\${GITHUB_REPOSITORY}.git /workspace
              cd /workspace
              if [ -n "\${GITHUB_REF}" ]; then
                git checkout \${GITHUB_REF}
              fi
            `],
            env: [
              { name: "GITHUB_REPOSITORY", valueFrom: { configMapKeyRef: { name: configMapName, key: "github_repository" } } },
              { name: "GITHUB_REF", valueFrom: { configMapKeyRef: { name: configMapName, key: "github_ref" } } },
              { name: "GITHUB_TOKEN", valueFrom: { secretKeyRef: { name: "claude-secrets", key: "github-token" } } }
            ],
            volumeMounts: [{ name: "workspace", mountPath: "/workspace" }]
          }],
          containers: [{
            name: "claude-runner",
            image: process.env.CLAUDE_RUNNER_IMAGE || "549574275832.dkr.ecr.us-east-1.amazonaws.com/claude-runner:latest",
            command: ["bun", "/app/src/coding/entrypoints/claude-runner.ts"],
            workingDir: "/workspace",
            env: [
              { name: "ANTHROPIC_API_KEY", valueFrom: { secretKeyRef: { name: "claude-secrets", key: "anthropic-api-key" } } },
              { name: "GITHUB_TOKEN", valueFrom: { secretKeyRef: { name: "claude-secrets", key: "github-token" } } },
              { name: "GITHUB_EVENT_NAME", valueFrom: { configMapKeyRef: { name: configMapName, key: "github_event_name" } } },
              { name: "GITHUB_EVENT_PAYLOAD", valueFrom: { configMapKeyRef: { name: configMapName, key: "github_event_payload" } } },
              { name: "CLAUDE_JOB_ID", valueFrom: { configMapKeyRef: { name: configMapName, key: "job_id" } } },
              { name: "CLAUDE_COMMENT_ID", valueFrom: { configMapKeyRef: { name: configMapName, key: "comment_id" } } },
              { name: "INPUT_ALLOWED_TOOLS", valueFrom: { configMapKeyRef: { name: configMapName, key: "allowed_tools" } } },
              { name: "INPUT_DISALLOWED_TOOLS", valueFrom: { configMapKeyRef: { name: configMapName, key: "disallowed_tools" } } },
              { name: "INPUT_MAX_TURNS", valueFrom: { configMapKeyRef: { name: configMapName, key: "max_turns" } } },
              { name: "INPUT_TIMEOUT_MINUTES", valueFrom: { configMapKeyRef: { name: configMapName, key: "timeout_minutes" } } },
              { name: "INPUT_SYSTEM_PROMPT", valueFrom: { configMapKeyRef: { name: configMapName, key: "system_prompt" } } },
              { name: "INPUT_APPEND_SYSTEM_PROMPT", valueFrom: { configMapKeyRef: { name: configMapName, key: "append_system_prompt" } } },
              { name: "INPUT_FALLBACK_MODEL", valueFrom: { configMapKeyRef: { name: configMapName, key: "fallback_model" } } },
              { name: "GITHUB_WORKSPACE", value: "/workspace" },
              { name: "RUNNER_TEMP", value: "/tmp" }
            ],
            volumeMounts: [
              { name: "workspace", mountPath: "/workspace" },
              { name: "prompt", mountPath: "/tmp/prompt.txt", subPath: "prompt.txt" },
              { name: "mcp-config", mountPath: "/tmp/mcp-config.json", subPath: "mcp-config.json" }
            ],
            resources: {
              requests: { memory: "2Gi", cpu: "1" },
              limits: { memory: "4Gi", cpu: "2" }
            }
          }],
          volumes: [
            { name: "workspace", emptyDir: {} },
            { name: "prompt", configMap: { name: configMapName, items: [{ key: "prompt", path: "prompt.txt" }] } },
            { name: "mcp-config", configMap: { name: configMapName, items: [{ key: "mcp_config", path: "mcp-config.json" }] } }
          ]
        }
      }
    };
    
    await k8s.createJob(jobName, namespace, jobSpec);
    console.log(`✅ Created Job: ${jobName}`);
    
  } catch (error) {
    console.error("❌ Failed to create Kubernetes resources:", error);
    throw error;
  }
}

// Main webhook server
if (import.meta.main) {
  const port = parseInt(process.env.PORT || "9000");
  
  Bun.serve({
    port,
    async fetch(req) {
      const url = new URL(req.url);
      
      if (url.pathname === "/health") {
        return new Response("OK", { status: 200 });
      }
      
      if (url.pathname === "/webhook/claude" && req.method === "POST") {
        try {
          // Verify webhook signature if configured
          const secret = process.env.WEBHOOK_SECRET;
          if (secret) {
            const signature = req.headers.get("x-hub-signature-256");
            if (!signature) {
              return new Response("Missing signature", { status: 401 });
            }
            
            const body = await req.text();
            const expected = `sha256=${createHash('sha256').update(secret).update(body).digest('hex')}`;
            
            if (signature !== expected) {
              return new Response("Invalid signature", { status: 401 });
            }
            
            await handleClaudeWebhook(JSON.parse(body));
          } else {
            const payload = await req.json();
            await handleClaudeWebhook(payload as WebhookPayload);
          }
          
          return new Response("OK", { status: 200 });
        } catch (error) {
          console.error("Webhook error:", error);
          return new Response("Internal Server Error", { status: 500 });
        }
      }
      
      return new Response("Not Found", { status: 404 });
    }
  });
  
  console.log(`🚀 Claude webhook server listening on port ${port}`);
}