#!/usr/bin/env bun
/**
 * Simple Webhook Server for Claude Code Testing
 * 
 * Receives GitHub webhooks and demonstrates the integration.
 */

import express from "express";
import crypto from "crypto";
import { handleWebhook } from "../coding/entrypoints/webhook-handler";

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
    console.log('🔔 Received webhook request');
    
    // Verify signature
    const signature = req.headers['x-hub-signature-256'] as string;
    if (!signature) {
      console.error('❌ Missing signature header');
      return res.status(401).json({ error: 'Missing signature' });
    }

    if (!verifySignature(req.body, signature, WEBHOOK_SECRET)) {
      console.error('❌ Invalid signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    // Parse payload
    const payload = JSON.parse(req.body.toString());
    const eventName = req.headers['x-github-event'] as string;

    console.log(`📨 Processing ${eventName} event for ${payload.repository?.full_name}`);
    
    // Use the real Claude Code webhook handler
    console.log('🚀 Processing with real Claude Code system...');
    
    const result = await handleWebhook(payload, eventName);
    
    if (result.success) {
      console.log(`✅ Claude Code job submitted: ${result.jobId}`);
    } else {
      console.log(`❌ Claude Code processing failed: ${result.message}`);
    }
    
    res.json(result);

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`💥 Webhook handler error: ${errorMessage}`);
    
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
    console.log('🔧 Received terragrunt deploy webhook');
    
    // Verify signature
    const signature = req.headers['x-hub-signature-256'] as string;
    if (signature && !verifySignature(req.body, signature, WEBHOOK_SECRET)) {
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const payload = JSON.parse(req.body.toString());
    console.log(`📦 Terragrunt deploy triggered for ${payload.repository?.clone_url}`);
    
    res.json({
      success: true,
      message: "Terragrunt deploy webhook received"
    });

  } catch (error) {
    console.error(`💥 Terragrunt webhook error: ${error}`);
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
    version: '1.0.0-simple',
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
  res.json({
    service: 'Agentic Coding Webhook Server',
    endpoints: {
      '/hooks/agent-issue-router': 'GitHub issues and PRs webhook handler (Real Claude Code SDK)',
      '/hooks/terragrunt-deploy': 'Terragrunt deployment webhook',
      '/health': 'Health check',
      '/status': 'This endpoint'
    },
    environment: {
      webhookSecret: process.env.WEBHOOK_SECRET ? 'configured' : 'missing',
      githubToken: process.env.GITHUB_TOKEN ? 'configured' : 'missing',
      nomadAddr: process.env.NOMAD_ADDR || 'http://localhost:4646',
      anthropicApiKey: process.env.ANTHROPIC_API_KEY ? 'configured' : 'missing'
    },
    features: [
      'GitHub webhook signature verification',
      'Claude Code SDK Python runtime integration',
      'Real Claude Code execution with MCP servers',
      'Nomad job orchestration',
      'GitHub API integration for comments and branches',
      'Terragrunt and infrastructure tool access'
    ],
    lastRestart: new Date().toISOString()
  });
});

// Error handling middleware
app.use((error: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('💥 Unhandled error:', error);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: error.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Agentic Coding Webhook Server (Simple) listening on port ${PORT}`);
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
  console.log(`🎯 Ready to receive Claude Code triggers!`);
});

export default app;