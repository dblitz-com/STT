#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import { Octokit } from '@octokit/rest';
import { z } from 'zod';

// Schema definitions for our tools
const UpdateCommentSchema = z.object({
  owner: z.string().describe('Repository owner'),
  repo: z.string().describe('Repository name'),
  commentId: z.number().describe('GitHub comment ID to update'),
  body: z.string().describe('New comment body content'),
  isPullRequestReviewComment: z.boolean().optional().describe('Whether this is a PR review comment')
});

const GetPRDiffSchema = z.object({
  owner: z.string().describe('Repository owner'),
  repo: z.string().describe('Repository name'),
  pullNumber: z.number().describe('Pull request number'),
  format: z.enum(['full', 'summary', 'files']).optional().default('full').describe('Diff format')
});

const CreateInitialCommentSchema = z.object({
  owner: z.string().describe('Repository owner'),
  repo: z.string().describe('Repository name'),
  issueNumber: z.number().describe('Issue or PR number'),
  body: z.string().describe('Initial comment body')
});

class GitHubOperationsServer {
  private server: Server;
  private octokit: Octokit;

  constructor() {
    this.server = new Server(
      {
        name: 'github_file_ops',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Initialize Octokit with token from environment
    const token = process.env.GITHUB_TOKEN;
    if (!token) {
      throw new Error('GITHUB_TOKEN environment variable is required');
    }
    
    this.octokit = new Octokit({ auth: token });

    this.setupHandlers();
  }

  private setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'update_claude_comment',
          description: 'Update an existing GitHub comment (for progress tracking)',
          inputSchema: {
            type: 'object',
            properties: {
              owner: { type: 'string', description: 'Repository owner' },
              repo: { type: 'string', description: 'Repository name' },
              commentId: { type: 'number', description: 'GitHub comment ID to update' },
              body: { type: 'string', description: 'New comment body content' },
              isPullRequestReviewComment: { 
                type: 'boolean', 
                description: 'Whether this is a PR review comment',
                default: false
              }
            },
            required: ['owner', 'repo', 'commentId', 'body']
          }
        },
        {
          name: 'get_pr_diff',
          description: 'Get pull request diff for code review',
          inputSchema: {
            type: 'object',
            properties: {
              owner: { type: 'string', description: 'Repository owner' },
              repo: { type: 'string', description: 'Repository name' },
              pullNumber: { type: 'number', description: 'Pull request number' },
              format: { 
                type: 'string', 
                enum: ['full', 'summary', 'files'],
                description: 'Diff format (full includes patch, summary is metadata only)',
                default: 'full'
              }
            },
            required: ['owner', 'repo', 'pullNumber']
          }
        },
        {
          name: 'create_initial_comment',
          description: 'Create initial tracking comment on issue or PR',
          inputSchema: {
            type: 'object',
            properties: {
              owner: { type: 'string', description: 'Repository owner' },
              repo: { type: 'string', description: 'Repository name' },
              issueNumber: { type: 'number', description: 'Issue or PR number' },
              body: { type: 'string', description: 'Initial comment body' }
            },
            required: ['owner', 'repo', 'issueNumber', 'body']
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'update_claude_comment':
            return await this.updateComment(args);
          case 'get_pr_diff':
            return await this.getPRDiff(args);
          case 'create_initial_comment':
            return await this.createInitialComment(args);
          default:
            throw new McpError(
              ErrorCode.MethodNotFound,
              `Unknown tool: ${name}`
            );
        }
      } catch (error) {
        if (error instanceof McpError) {
          throw error;
        }
        throw new McpError(
          ErrorCode.InternalError,
          `Tool execution failed: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }
    });
  }

  private async updateComment(args: unknown) {
    const params = UpdateCommentSchema.parse(args);
    
    try {
      let response;
      
      if (params.isPullRequestReviewComment) {
        // Try PR review comment API first
        try {
          response = await this.octokit.rest.pulls.updateReviewComment({
            owner: params.owner,
            repo: params.repo,
            comment_id: params.commentId,
            body: params.body,
          });
        } catch (error: any) {
          // If PR review comment fails with 404, try issue comment API
          if (error.status === 404) {
            response = await this.octokit.rest.issues.updateComment({
              owner: params.owner,
              repo: params.repo,
              comment_id: params.commentId,
              body: params.body,
            });
          } else {
            throw error;
          }
        }
      } else {
        // Use issue comment API (works for both issues and PR general comments)
        response = await this.octokit.rest.issues.updateComment({
          owner: params.owner,
          repo: params.repo,
          comment_id: params.commentId,
          body: params.body,
        });
      }

      return {
        content: [
          {
            type: 'text',
            text: `Successfully updated comment ${params.commentId}`
          }
        ]
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to update comment: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  private async getPRDiff(args: unknown) {
    const params = GetPRDiffSchema.parse(args);
    
    try {
      // Get PR information
      const { data: pr } = await this.octokit.rest.pulls.get({
        owner: params.owner,
        repo: params.repo,
        pull_number: params.pullNumber,
      });

      // Get files changed
      const { data: files } = await this.octokit.rest.pulls.listFiles({
        owner: params.owner,
        repo: params.repo,
        pull_number: params.pullNumber,
        per_page: 100, // Max 100 files
      });

      let content = '';

      if (params.format === 'summary') {
        // Summary format - just metadata
        content = `## PR #${params.pullNumber}: ${pr.title}\n\n`;
        content += `**Author:** @${pr.user?.login}\n`;
        content += `**Base:** ${pr.base.ref} ← **Head:** ${pr.head.ref}\n`;
        content += `**Changes:** +${pr.additions} -${pr.deletions} in ${files.length} files\n\n`;
        
        content += '### Files Changed:\n';
        for (const file of files) {
          content += `- ${file.filename} (+${file.additions} -${file.deletions})`;
          if (file.status === 'renamed') {
            content += ` (renamed from ${file.previous_filename})`;
          }
          content += '\n';
        }
      } else if (params.format === 'files') {
        // Just list of files
        content = files.map(f => f.filename).join('\n');
      } else {
        // Full format - include patches
        content = `## PR #${params.pullNumber}: ${pr.title}\n\n`;
        content += `**Author:** @${pr.user?.login}\n`;
        content += `**Base:** ${pr.base.ref} ← **Head:** ${pr.head.ref}\n\n`;
        
        content += '### Description:\n';
        content += pr.body || 'No description provided.';
        content += '\n\n### Changes:\n\n';

        for (const file of files) {
          content += `#### ${file.filename}`;
          if (file.status === 'renamed') {
            content += ` (renamed from ${file.previous_filename})`;
          }
          content += '\n';
          content += `Changes: +${file.additions} -${file.deletions}\n\n`;
          
          if (file.patch) {
            content += '```diff\n';
            content += file.patch;
            content += '\n```\n\n';
          } else if (file.status === 'added') {
            content += '*New file*\n\n';
          } else if (file.status === 'removed') {
            content += '*File deleted*\n\n';
          }
        }
      }

      return {
        content: [
          {
            type: 'text',
            text: content
          }
        ]
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to get PR diff: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  private async createInitialComment(args: unknown) {
    const params = CreateInitialCommentSchema.parse(args);
    
    try {
      const response = await this.octokit.rest.issues.createComment({
        owner: params.owner,
        repo: params.repo,
        issue_number: params.issueNumber,
        body: params.body,
      });

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              commentId: response.data.id,
              url: response.data.html_url
            })
          }
        ]
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to create comment: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('GitHub File Ops MCP server running on stdio');
  }
}

// Start the server
const server = new GitHubOperationsServer();
server.run().catch(console.error);