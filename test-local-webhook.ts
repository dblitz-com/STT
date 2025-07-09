#!/usr/bin/env bun

import { handleLocalWebhook } from './src/coding/entrypoints/local-webhook-handler';

async function testLocalWebhook() {
  console.log("🧪 Testing updated GitHub Actions-style local webhook handler");
  
  const payload = {
    action: 'created',
    issue: { 
      number: 16,
      title: 'Test hello world creation',
      body: '@Claude create a hello world TypeScript file that prints "Hello from Claude Code!"',
      user: { login: 'dBlitz' }
    },
    comment: { 
      id: 123,
      body: '@Claude create a hello world TypeScript file that prints "Hello from Claude Code!"',
      user: { login: 'dBlitz' }
    },
    repository: { 
      full_name: 'dblitz-com/gengine',
      name: 'gengine', 
      owner: { login: 'dblitz-com' },
      clone_url: 'https://github.com/dblitz-com/gengine.git'
    },
    sender: {
      login: 'dBlitz',
      type: 'User'
    }
  };

  try {
    const result = await handleLocalWebhook(payload, 'issue_comment');
    console.log("🎉 Test Result:", result);
    
    if (result.success && result.executionId) {
      console.log(`✅ SUCCESS! Execution ID: ${result.executionId}`);
      console.log("Now Claude should have created and committed a hello world file!");
    } else {
      console.log("❌ Test failed:", result.message);
    }
  } catch (error) {
    console.error("❌ Test error:", error);
  }
}

// Run the test
testLocalWebhook();