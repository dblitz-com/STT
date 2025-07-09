#!/bin/bash
# Automated GitHub webhook configuration using API

set -e

# Configuration
GITHUB_REPO="dblitz-com/gengine"
WEBHOOK_PATH="/hooks/agent-issue-router"

echo "🚀 Automated GitHub Webhook Configuration"
echo "========================================"
echo

# Check for required environment variables
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN environment variable not set"
    echo "Export your GitHub personal access token with repo:hook permissions:"
    echo "export GITHUB_TOKEN=ghp_your_token_here"
    exit 1
fi

# Step 1: Get webhook endpoint
echo "📍 Getting webhook endpoint..."
WEBHOOK_URL=""

# Try to get LoadBalancer IP
LB_IP=$(kubectl get svc webhook-server -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [ -n "$LB_IP" ]; then
    WEBHOOK_URL="http://${LB_IP}${WEBHOOK_PATH}"
    echo "✅ Found LoadBalancer IP: $LB_IP"
else
    # Try to get LoadBalancer hostname
    LB_HOST=$(kubectl get svc webhook-server -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    if [ -n "$LB_HOST" ]; then
        WEBHOOK_URL="http://${LB_HOST}${WEBHOOK_PATH}"
        echo "✅ Found LoadBalancer hostname: $LB_HOST"
    else
        # Check for Ingress
        INGRESS_HOST=$(kubectl get ingress webhook-server -n default -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)
        if [ -n "$INGRESS_HOST" ]; then
            WEBHOOK_URL="http://${INGRESS_HOST}${WEBHOOK_PATH}"
            echo "✅ Found Ingress host: $INGRESS_HOST"
        else
            echo "❌ Could not find webhook endpoint. Please enter manually:"
            read -p "Webhook URL: " WEBHOOK_URL
        fi
    fi
fi

echo "📡 Webhook URL: $WEBHOOK_URL"

# Step 2: Get or create webhook secret
echo
echo "🔐 Getting webhook secret..."
WEBHOOK_SECRET=$(kubectl get secret example-app-secrets -n default -o jsonpath='{.data.webhook-secret}' 2>/dev/null | base64 -d || true)

if [ -z "$WEBHOOK_SECRET" ]; then
    echo "⚠️  Secret not found, creating new one..."
    WEBHOOK_SECRET=$(openssl rand -hex 32)
    kubectl create secret generic example-app-secrets \
        --from-literal=webhook-secret=$WEBHOOK_SECRET \
        -n default \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "✅ Created new webhook secret"
else
    echo "✅ Found existing webhook secret"
fi

# Step 3: Check if webhook already exists
echo
echo "🔍 Checking existing webhooks..."
EXISTING_WEBHOOK=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${GITHUB_REPO}/hooks" | \
    jq -r ".[] | select(.config.url == \"${WEBHOOK_URL}\") | .id")

if [ -n "$EXISTING_WEBHOOK" ]; then
    echo "⚠️  Webhook already exists with ID: $EXISTING_WEBHOOK"
    read -p "Delete and recreate? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        curl -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/${GITHUB_REPO}/hooks/${EXISTING_WEBHOOK}"
        echo "✅ Deleted existing webhook"
    else
        echo "Keeping existing webhook"
        exit 0
    fi
fi

# Step 4: Create webhook
echo
echo "📝 Creating GitHub webhook..."

WEBHOOK_CONFIG=$(cat <<EOF
{
  "name": "web",
  "active": true,
  "events": [
    "issue_comment",
    "issues",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment"
  ],
  "config": {
    "url": "${WEBHOOK_URL}",
    "content_type": "json",
    "secret": "${WEBHOOK_SECRET}",
    "insecure_ssl": "0"
  }
}
EOF
)

RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$WEBHOOK_CONFIG" \
    "https://api.github.com/repos/${GITHUB_REPO}/hooks")

WEBHOOK_ID=$(echo "$RESPONSE" | jq -r '.id')

if [ "$WEBHOOK_ID" != "null" ] && [ -n "$WEBHOOK_ID" ]; then
    echo "✅ Webhook created successfully! ID: $WEBHOOK_ID"
    echo
    echo "📊 Webhook Details:"
    echo "$RESPONSE" | jq '{id, active, events, config: {url: .config.url, content_type: .config.content_type}}'
else
    echo "❌ Failed to create webhook"
    echo "Response: $RESPONSE"
    exit 1
fi

# Step 5: Test webhook
echo
echo "🧪 Testing webhook..."
echo "Sending test ping..."

TEST_RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${GITHUB_REPO}/hooks/${WEBHOOK_ID}/pings")

echo "✅ Test ping sent!"
echo
echo "📋 Next Steps:"
echo "1. Check webhook delivery at: https://github.com/${GITHUB_REPO}/settings/hooks"
echo "2. Monitor webhook server logs: kubectl logs -f deployment/webhook-server -n default"
echo "3. Create a test issue and comment with: @claude help"
echo
echo "🎉 Webhook configuration complete!"