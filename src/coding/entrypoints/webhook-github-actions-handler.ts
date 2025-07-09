#!/usr/bin/env bun
/**
 * ⭐ OPTION A - GITHUB ACTIONS INTEGRATION ⭐
 * 
 * PREFERRED SOLUTION: Uses GitHub Actions self-hosted runners
 * 
 * This webhook handler triggers GitHub Actions workflows instead of creating
 * Kubernetes Jobs. It provides proper GitHub Actions context and status comments.
 * 
 * Prerequisites:
 * - GitHub Actions self-hosted runners deployed (see infrastructure/github-actions-runners/)
 * - Claude Code Action workflow configured in .github/workflows/
 * 
 * Webhook Handler for Claude Code Actions via GitHub Actions
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

interface GitHubAPIClient {
  triggerWorkflow(owner: string, repo: string, workflowId: string, ref: string, inputs: Record<string, any>): Promise<void>;
  createRepositoryDispatch(owner: string, repo: string, eventType: string, clientPayload: any): Promise<void>;
}

// GitHub API client
class GitHubClient implements GitHubAPIClient {
  private token: string;
  private baseUrl: string;

  constructor(token: string, baseUrl = "https://api.github.com") {
    this.token = token;
    this.baseUrl = baseUrl;
  }

  private async makeRequest(endpoint: string, method: string = "POST", body?: any): Promise<any> {
    const url = `${this.baseUrl}${endpoint}`;
    const response = await fetch(url, {
      method,
      headers: {
        "Authorization": `Bearer ${this.token}`,
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
        "User-Agent": "Claude-Code-Webhook/1.0"
      },
      body: body ? JSON.stringify(body) : undefined
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`GitHub API error ${response.status}: ${error}`);
    }

    return response.json();
  }

  async triggerWorkflow(owner: string, repo: string, workflowId: string, ref: string, inputs: Record<string, any>): Promise<void> {
    const endpoint = `/repos/${owner}/${repo}/actions/workflows/${workflowId}/dispatches`;
    await this.makeRequest(endpoint, "POST", {
      ref,
      inputs
    });
  }

  async createRepositoryDispatch(owner: string, repo: string, eventType: string, clientPayload: any): Promise<void> {
    const endpoint = `/repos/${owner}/${repo}/dispatches`;
    await this.makeRequest(endpoint, "POST", {
      event_type: eventType,
      client_payload: clientPayload
    });
  }
}

export async function handleClaudeWebhook(payload: WebhookPayload): Promise<void> {
  console.log("🔔 Received webhook for Claude Code Action (GitHub Actions mode)");
  
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
  
  console.log("✅ Trigger phrase found, triggering GitHub Actions workflow...");
  
  // Extract repository information
  const owner = payload.repository.owner.login;
  const repo = payload.repository.name;
  const entity = payload.issue || payload.pull_request;
  const eventName = payload.issue ? "issues" : "pull_request";
  
  // GitHub API client
  const githubToken = process.env.GITHUB_TOKEN;
  if (!githubToken) {
    throw new Error("GITHUB_TOKEN environment variable is required");
  }
  
  const github = new GitHubClient(githubToken, process.env.GITHUB_API_URL);
  
  try {
    // Option 1: Trigger workflow_dispatch (preferred if you have a dedicated workflow)
    const workflowFile = process.env.CLAUDE_WORKFLOW_FILE || "claude-code.yml";
    const workflowRef = process.env.CLAUDE_WORKFLOW_REF || payload.repository.default_branch;
    
    const workflowInputs = {
      // GitHub context
      github_event_name: eventName,
      github_repository: payload.repository.full_name,
      github_ref: entity.head?.ref || payload.repository.default_branch,
      github_sha: entity.head?.sha || "",
      
      // Issue/PR context
      issue_number: entity.number.toString(),
      comment_id: comment.id.toString(),
      comment_body: comment.body,
      comment_author: comment.user.login,
      
      // Entity context
      entity_title: entity.title || "",
      entity_body: entity.body || "",
      entity_author: entity.user.login,
      entity_url: entity.html_url,
      
      // Configuration
      trigger_phrase: triggerPhrase,
      allowed_tools: process.env.ALLOWED_TOOLS || "Edit,MultiEdit,Glob,Grep,LS,Read,Write,Bash,mcp__github_file_ops__commit_files,mcp__github_file_ops__delete_files,mcp__github_file_ops__update_claude_comment",
      disallowed_tools: process.env.DISALLOWED_TOOLS || "",
      max_turns: process.env.MAX_TURNS || "10",
      timeout_minutes: process.env.TIMEOUT_MINUTES || "30",
      system_prompt: process.env.SYSTEM_PROMPT || "",
      append_system_prompt: process.env.APPEND_SYSTEM_PROMPT || "",
      fallback_model: process.env.FALLBACK_MODEL || ""
    };
    
    try {
      // Try workflow_dispatch first
      await github.triggerWorkflow(owner, repo, workflowFile, workflowRef, workflowInputs);
      console.log(`✅ Triggered workflow_dispatch for ${workflowFile}`);
      
    } catch (workflowError) {
      console.log(`ℹ️ workflow_dispatch failed (${workflowError.message}), trying repository_dispatch...`);
      
      // Option 2: Use repository_dispatch as fallback
      const clientPayload = {
        github: {
          event_name: eventName,
          repository: payload.repository.full_name,
          ref: entity.head?.ref || payload.repository.default_branch,
          sha: entity.head?.sha || ""
        },
        entity: {
          type: eventName,
          number: entity.number,
          title: entity.title || "",
          body: entity.body || "",
          author: entity.user.login,
          url: entity.html_url
        },
        comment: {
          id: comment.id,
          body: comment.body,
          author: comment.user.login,
          url: comment.html_url
        },
        config: {
          trigger_phrase: triggerPhrase,
          allowed_tools: workflowInputs.allowed_tools,
          disallowed_tools: workflowInputs.disallowed_tools,
          max_turns: workflowInputs.max_turns,
          timeout_minutes: workflowInputs.timeout_minutes,
          system_prompt: workflowInputs.system_prompt,
          append_system_prompt: workflowInputs.append_system_prompt,
          fallback_model: workflowInputs.fallback_model
        },
        webhook: {
          timestamp: new Date().toISOString(),
          source: "claude-code-webhook"
        }
      };
      
      await github.createRepositoryDispatch(owner, repo, "claude-code", clientPayload);
      console.log(`✅ Triggered repository_dispatch for claude-code event`);
    }
    
  } catch (error) {
    console.error("❌ Failed to trigger GitHub Actions workflow:", error);
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
  
  console.log(`🚀 Claude GitHub Actions webhook server listening on port ${port}`);
  console.log(`🎯 Mode: GitHub Actions (Option A - Preferred)`);
  console.log(`📋 Workflow file: ${process.env.CLAUDE_WORKFLOW_FILE || "claude-code.yml"}`);
  console.log(`🌿 Workflow ref: ${process.env.CLAUDE_WORKFLOW_REF || "main"}`);
}