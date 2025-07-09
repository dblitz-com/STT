#!/bin/bash
# Test Claude Code webhook - Simple TypeScript file creation

WEBHOOK_URL="http://localhost:9000/hooks/agent-issue-router"
WEBHOOK_SECRET="bb2a9a1d476c3a69ff52fb2a3503bb8c339eb068c11e81f19b8754b18c3c4fa6"

# Create test payload - exactly like the working one from logs
PAYLOAD='{
  "action": "created",
  "issue": {
    "number": 15,
    "title": "Test Claude Code Integration",
    "body": "This is a test issue to verify our Claude Code integration works.",
    "user": {
      "login": "dBlitz"
    },
    "assignee": null
  },
  "comment": {
    "id": 123456789,
    "body": "@claude Please help me implement a simple hello world function in TypeScript. Create a new file called hello.ts with a function that returns Hello, World!",
    "user": {
      "login": "dBlitz"
    }
  },
  "repository": {
    "full_name": "dblitz-com/gengine",
    "owner": {
      "login": "dblitz-com"
    },
    "name": "gengine",
    "clone_url": "https://github.com/dblitz-com/gengine.git"
  },
  "sender": {
    "login": "dBlitz"
  }
}'

# Calculate HMAC signature
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | sed 's/^.* //')

# Send webhook request
echo "🧪 Testing Claude Code webhook..."
echo "📝 Trigger: @claude create simple TypeScript hello.ts"
echo "🎯 Webhook URL: $WEBHOOK_URL"
echo ""

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIGNATURE" \
  -H "X-GitHub-Event: issue_comment" \
  -d "$PAYLOAD" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

echo ""
echo "✅ Webhook sent! Check webhook-server.log for streaming output"