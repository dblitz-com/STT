#!/bin/bash
# Script to help set up GitHub webhook for Claude Code

echo "🔧 GitHub Webhook Setup for Claude Code"
echo "======================================="
echo

# Step 1: Get webhook endpoint
echo "📍 Step 1: Finding webhook endpoint..."
echo "Run these commands to find your webhook URL:"
echo
echo "# Option A: If using LoadBalancer service"
echo "kubectl get svc webhook-server -n default"
echo "# Look for EXTERNAL-IP, then use: http://<EXTERNAL-IP>/hooks/agent-issue-router"
echo
echo "# Option B: If using Ingress"
echo "kubectl get ingress webhook-server -n default"
echo "# Use the configured host: http://webhook.gengine.local/hooks/agent-issue-router"
echo
echo "# Option C: If using bastion host webhook"
echo "# Check infrastructure/WEBHOOK_AUTOMATION.md for bastion IP"
echo

# Step 2: Get webhook secret
echo "🔐 Step 2: Get webhook secret..."
echo "Run this command to get your webhook secret:"
echo
echo "kubectl get secret example-app-secrets -n default -o jsonpath='{.data.webhook-secret}' | base64 -d"
echo
echo "If the secret doesn't exist, create it with:"
echo "WEBHOOK_SECRET=\$(openssl rand -hex 32)"
echo "kubectl create secret generic example-app-secrets --from-literal=webhook-secret=\$WEBHOOK_SECRET -n default"
echo

# Step 3: GitHub webhook configuration
echo "🌐 Step 3: Configure GitHub Webhook"
echo "===================================="
echo
echo "1. Go to: https://github.com/dblitz-com/gengine/settings/hooks"
echo "2. Click 'Add webhook'"
echo "3. Configure with:"
echo
echo "   Payload URL:  <YOUR_WEBHOOK_ENDPOINT>/hooks/agent-issue-router"
echo "   Content type: application/json"
echo "   Secret:       <YOUR_WEBHOOK_SECRET>"
echo
echo "4. Which events would you like to trigger this webhook?"
echo "   🔘 Let me select individual events:"
echo "      ✅ Issue comments"
echo "      ✅ Issues"
echo "      ✅ Pull requests"
echo "      ✅ Pull request reviews"
echo "      ✅ Pull request review comments"
echo
echo "5. ✅ Active"
echo "6. Click 'Add webhook'"
echo

# Step 4: Test the webhook
echo "🧪 Step 4: Test the webhook"
echo "==========================="
echo
echo "1. Create a test issue in the repository"
echo "2. Comment with: @claude help me understand this codebase"
echo "3. Check if Claude responds!"
echo
echo "📊 Monitor webhook delivery:"
echo "   - GitHub: Settings > Webhooks > Recent Deliveries"
echo "   - Kubernetes: kubectl logs -f deployment/webhook-server -n default"
echo "   - Jobs: kubectl get jobs -n default -w"
echo

# Generate a webhook secret if needed
echo "💡 Quick setup commands:"
echo "========================"
echo
cat << 'EOF'
# Generate webhook secret
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo "Webhook Secret: $WEBHOOK_SECRET"

# Create Kubernetes secret
kubectl create secret generic example-app-secrets \
  --from-literal=webhook-secret=$WEBHOOK_SECRET \
  -n default \
  --dry-run=client -o yaml | kubectl apply -f -

# Get webhook endpoint (choose one)
kubectl get svc webhook-server -n default  # For LoadBalancer
kubectl get ingress webhook-server -n default  # For Ingress

# Watch for webhook server logs
kubectl logs -f deployment/webhook-server -n default
EOF