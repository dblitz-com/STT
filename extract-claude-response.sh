#!/bin/bash
# Extract Claude's response comment from webhook test

echo "🔍 Extracting Claude's GitHub comment response..."
echo ""

# Test the webhook and extract just the comment
RESPONSE=$(curl -s -X POST "http://localhost:3000/hooks/agent-issue-router" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$(echo -n '{
  "action": "created",
  "issue": {
    "number": 15,
    "title": "Test Claude Code Integration",
    "body": "This is a test issue to verify our Claude Code integration works.",
    "user": {"login": "testuser"}
  },
  "comment": {
    "id": 123456789,
    "body": "@claude Please help me implement a simple hello world function in TypeScript. Create a new file called hello.ts with a function that returns \"Hello, World!\"",
    "user": {"login": "testuser"}
  },
  "repository": {
    "full_name": "dblitz-com/gengine",
    "owner": {"login": "dblitz-com"},
    "name": "gengine",
    "clone_url": "https://github.com/dblitz-com/gengine.git"
  },
  "sender": {"login": "testuser"}
}' | openssl dgst -sha256 -hmac "bb2a9a1d476c3a69ff52fb2a3503bb8c339eb068c11e81f19b8754b18c3c4fa6" | sed 's/^.* //')" \
  -H "X-GitHub-Event: issue_comment" \
  -d '{
  "action": "created",
  "issue": {
    "number": 15,
    "title": "Test Claude Code Integration", 
    "body": "This is a test issue to verify our Claude Code integration works.",
    "user": {"login": "testuser"}
  },
  "comment": {
    "id": 123456789,
    "body": "@claude Please help me implement a simple hello world function in TypeScript. Create a new file called hello.ts with a function that returns \"Hello, World!\"",
    "user": {"login": "testuser"}
  },
  "repository": {
    "full_name": "dblitz-com/gengine",
    "owner": {"login": "dblitz-com"},
    "name": "gengine", 
    "clone_url": "https://github.com/dblitz-com/gengine.git"
  },
  "sender": {"login": "testuser"}
}')

# Extract the comment field and display it formatted
echo "📝 Claude's GitHub Comment Response:"
echo "=================================================="
echo "$RESPONSE" | jq -r '.result.comment' | sed 's/\\n/\n/g'
echo "=================================================="
echo ""

# Show other details
echo "🔧 Job Details:"
echo "Job ID: $(echo "$RESPONSE" | jq -r '.result.jobId')"
echo "Branch: $(echo "$RESPONSE" | jq -r '.result.branch')"
echo "Status: $(echo "$RESPONSE" | jq -r '.result.status')"
echo ""

echo "🎯 This is what would be posted as a comment on GitHub issue #15!"