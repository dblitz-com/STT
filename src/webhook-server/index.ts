#!/usr/bin/env bun
/**
 * Webhook Server for Agentic Coding System
 * 
 * Receives GitHub webhooks and triggers Claude Code execution.
 * Replaces the existing agent routing system.
 */

import express from "express";
import crypto from "crypto";
import { handleClaudeWebhook } from "../coding/entrypoints/webhook-claude-handler";

// Load environment variables from .env file
import dotenv from 'dotenv';
import path from 'path';

// Load .env from project root
dotenv.config({ path: path.join(__dirname, '../../.env') });

const app = express();
const PORT = process.env.PORT || 9000;
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || "bb2a9a1d476c3a69ff52fb2a3503bb8c339eb068c11e81f19b8754b18c3c4fa6";

// Middleware to parse JSON and raw body for signature verification
app.use('/hooks', express.raw({ type: 'application/json' }));

/**
 * Verify GitHub webhook signature
 */
function verifySignature(payload: Buffer, signature: string, secret: string): boolean {
  const computedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  const expectedSignature = `sha256=${computedSignature}`;
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

/**
 * GitHub webhook endpoint for issues and pull requests
 */
app.post('/hooks/agent-issue-router', async (req, res) => {
  try {
    console.log('Received webhook request');
    
    // Verify signature
    const signature = req.headers['x-hub-signature-256'] as string;
    if (!signature) {
      console.error('Missing signature header');
      return res.status(401).json({ error: 'Missing signature' });
    }

    if (!verifySignature(req.body, signature, WEBHOOK_SECRET)) {
      console.error('Invalid signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    // Parse payload
    const payload = JSON.parse(req.body.toString());
    const eventName = req.headers['x-github-event'] as string;

    console.log(`Processing ${eventName} event for ${payload.repository?.full_name}`);

    // Handle with our Claude Code system
    await handleClaudeWebhook(payload);
    
    const result = {
      success: true,
      message: "Claude job created"
    };

    if (result.success) {
      console.log(`✓ Successfully processed webhook: ${result.message}`);
      res.json({
        success: true,
        message: result.message,
        // Handle both jobId (cloud/Nomad) and executionId (local)
        jobId: (result as any).jobId || (result as any).executionId,
        executionId: (result as any).executionId,
        executionType: useLocal ? 'local' : 'cloud'
      });
    } else {
      console.error(`✗ Failed to process webhook: ${result.message}`);
      res.status(500).json({
        success: false,
        message: result.message
      });
    }

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`Webhook handler error: ${errorMessage}`);
    
    res.status(500).json({
      success: false,
      message: `Internal server error: ${errorMessage}`
    });
  }
});

/**
 * Keep the existing terragrunt deploy endpoint for compatibility
 */
app.post('/hooks/terragrunt-deploy', async (req, res) => {
  try {
    console.log('Received terragrunt deploy webhook');
    
    // Verify signature
    const signature = req.headers['x-hub-signature-256'] as string;
    if (!signature) {
      return res.status(401).json({ error: 'Missing signature' });
    }

    if (!verifySignature(req.body, signature, WEBHOOK_SECRET)) {
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const payload = JSON.parse(req.body.toString());
    const eventName = req.headers['x-github-event'] as string;
    console.log(`Terragrunt deploy triggered for ${payload.repository?.clone_url}, event: ${eventName}`);
    
    // Handle issue comments and PRs with Claude Code (in addition to deploy events)
    if (eventName === 'issue_comment' || eventName === 'issues' || eventName === 'pull_request' || eventName === 'pull_request_review_comment') {
      console.log(`Forwarding ${eventName} to Claude Code system`);
      
      // Handle with our Claude Code system
      await handleClaudeWebhook(payload);
      
      const result = {
        success: true,
        message: "Claude job created"
      };
      
      return res.json(result);
    }
    
    // For push events and other deploy-related events, just acknowledge
    res.json({
      success: true,
      message: "Terragrunt deploy webhook received"
    });

  } catch (error) {
    console.error(`Terragrunt webhook error: ${error}`);
    res.status(500).json({
      success: false,
      message: "Terragrunt webhook failed"
    });
  }
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'agentic-coding-webhook-server',
    timestamp: new Date().toISOString(),
    environment: {
      port: PORT,
      nodeEnv: process.env.NODE_ENV || 'development',
      hasWebhookSecret: !!process.env.WEBHOOK_SECRET,
      hasGithubToken: !!process.env.GITHUB_TOKEN,
      hasNomadAddr: !!process.env.NOMAD_ADDR
    }
  });
});

/**
 * Status endpoint showing webhook configuration
 */
app.get('/status', (req, res) => {
  const useLocal = process.env.NODE_ENV !== 'production' || process.env.FORCE_LOCAL_EXECUTION === 'true';
  
  res.json({
    endpoints: {
      '/hooks/agent-issue-router': 'GitHub issues and PRs webhook handler',
      '/hooks/terragrunt-deploy': 'Terragrunt deployment webhook',
      '/health': 'Health check',
      '/status': 'This endpoint'
    },
    executionMode: useLocal ? 'local' : 'cloud',
    environment: {
      nodeEnv: process.env.NODE_ENV || 'development',
      forceLocal: process.env.FORCE_LOCAL_EXECUTION || 'false',
      webhookSecret: process.env.WEBHOOK_SECRET ? 'configured' : 'missing',
      githubToken: process.env.GITHUB_TOKEN ? 'configured' : 'missing',
      nomadAddr: process.env.NOMAD_ADDR || 'http://localhost:4646',
      anthropicApiKey: process.env.ANTHROPIC_API_KEY ? 'configured' : 'missing'
    },
    lastRestart: new Date().toISOString()
  });
});

// Error handling middleware
app.use((error: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: error.message
  });
});


// Start server
app.listen(PORT, () => {
  console.log(`🚀 Agentic Coding Webhook Server listening on port ${PORT}`);
  console.log(`📋 Endpoints:`);
  console.log(`   POST /hooks/agent-issue-router - GitHub issues/PRs`);
  console.log(`   POST /hooks/terragrunt-deploy - Terragrunt deployments`);
  console.log(`   GET  /health - Health check`);
  console.log(`   GET  /status - Configuration status`);
  console.log(`🔧 Environment:`);
  console.log(`   WEBHOOK_SECRET: ${process.env.WEBHOOK_SECRET ? 'configured' : 'missing'}`);
  console.log(`   GITHUB_TOKEN: ${process.env.GITHUB_TOKEN ? 'configured' : 'missing'}`);
  console.log(`   NOMAD_ADDR: ${process.env.NOMAD_ADDR || 'http://localhost:4646'}`);
  console.log(`   ANTHROPIC_API_KEY: ${process.env.ANTHROPIC_API_KEY ? 'configured' : 'missing'}`);
});

export default app;