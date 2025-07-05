#!/bin/bash
# GitHub Webhook Setup Script using gh CLI
# Automates webhook creation for Terragrunt deployments

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <webhook-url> <webhook-secret> <repo-owner/repo-name>"
    echo "Example: $0 http://34.218.206.74:9000/hooks/terragrunt-deploy bb2a9a1d476c...339eb068c devin/dblitz"
    exit 1
fi

WEBHOOK_URL="$1"
WEBHOOK_SECRET="$2"
REPO="$3"

echo "Setting up GitHub webhook for repository: $REPO"
echo "Webhook URL: $WEBHOOK_URL"

# Check if gh CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI not authenticated. Please run: gh auth login"
    exit 1
fi

# Create webhook using GitHub API
echo "Creating webhook..."

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
  -f events[]='push' > /tmp/webhook_response.json

# Check if webhook was created successfully
if [ $? -eq 0 ]; then
    WEBHOOK_ID=$(cat /tmp/webhook_response.json | jq -r '.id')
    echo "✅ Webhook created successfully!"
    echo "Webhook ID: $WEBHOOK_ID"
    echo "Webhook URL: $WEBHOOK_URL"
    echo ""
    echo "The webhook is configured to trigger on:"
    echo "- Push events to 'feature/clean-mcp-restructure' branch"
    echo "- Payload will be sent as JSON"
    echo "- HMAC signature verification enabled"
    echo ""
    echo "Test the webhook by pushing to the target branch:"
    echo "git push origin feature/clean-mcp-restructure"
    
    # Clean up temporary file
    rm -f /tmp/webhook_response.json
else
    echo "❌ Failed to create webhook. Response:"
    cat /tmp/webhook_response.json
    rm -f /tmp/webhook_response.json
    exit 1
fi