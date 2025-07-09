#!/bin/bash
# GitHub Issue Webhook Setup Script
# Creates or updates webhook for GitHub issue events to trigger agentic coding system

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <webhook-url> <webhook-secret> <repo-owner/repo-name>"
    echo "Example: $0 http://34.219.243.51:9000/hooks/agent-issue-router bb2a9a1d476c...339eb068c devin/dblitz"
    exit 1
fi

WEBHOOK_URL="$1"
WEBHOOK_SECRET="$2"
REPO="$3"

echo "Setting up GitHub issue webhook for repository: $REPO"
echo "Webhook URL: $WEBHOOK_URL"

# Check if gh CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI not authenticated. Please run: gh auth login"
    exit 1
fi

# Create webhook using GitHub API for issue events
echo "Creating issue webhook..."

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/hooks" \
  -f name='web' \
  -F active=true \
  -F config[url]="$WEBHOOK_URL" \
  -F config[content_type]='json' \
  -F config[secret]="$WEBHOOK_SECRET" \
  -F config[insecure_ssl]=0 \
  -f events[]='issues' \
  -f events[]='issue_comment' > /tmp/issue_webhook_response.json

# Check if webhook was created successfully
if [ $? -eq 0 ]; then
    WEBHOOK_ID=$(cat /tmp/issue_webhook_response.json | jq -r '.id')
    echo "✅ Issue webhook created successfully!"
    echo "Webhook ID: $WEBHOOK_ID"
    echo "Webhook URL: $WEBHOOK_URL"
    echo ""
    echo "The webhook is configured to trigger on:"
    echo "- Issue events (opened, closed, edited, etc.)"
    echo "- Issue comment events"
    echo "- Payload will be sent as JSON"
    echo "- HMAC signature verification enabled"
    echo ""
    echo "Test the webhook by creating a new issue:"
    echo "gh issue create --title 'Test Agent Routing' --body 'This is a test issue for the agentic coding system'"
    
    # Clean up temporary file
    rm -f /tmp/issue_webhook_response.json
else
    echo "❌ Failed to create issue webhook. Response:"
    cat /tmp/issue_webhook_response.json
    rm -f /tmp/issue_webhook_response.json
    exit 1
fi

echo ""
echo "🤖 Agentic Coding System Configuration:"
echo "  - Issues will be automatically routed to appropriate agents"
echo "  - Agent types: coder, tester, reviewer, docs"
echo "  - Priority classification based on labels and content"
echo "  - Logs available at: /opt/webhook/logs/agent-routing.log"
echo ""
echo "Related to GitHub Issue #15: Implement Agentic Coding System with Claude Code SDK Python Runtime"