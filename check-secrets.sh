#!/bin/bash
# Script to check which secrets we need

echo "🔍 Checking required secrets for Claude Code integration..."
echo

echo "📋 Required secrets based on our configuration:"
echo "1. claude-secrets (namespace: default)"
echo "   - anthropic-api-key"
echo "   - github-token"
echo "2. github-token-secret (namespace: default)"
echo "   - token"
echo "3. example-app-secrets (namespace: default)"
echo "   - webhook-secret"
echo "4. ecr-credentials (namespace: flux-system)"
echo "   - For pushing Docker images to ECR"
echo

echo "📍 References in our code:"
grep -h "secretKeyRef:" infrastructure/apps/base/webhook-server-deployment.yaml infrastructure/apps/base/claude-job.yaml | sort | uniq

echo
echo "🔐 To create these secrets (if not already created):"
echo
echo "# 1. Claude secrets"
echo "kubectl create secret generic claude-secrets \\"
echo "  --from-literal=anthropic-api-key=YOUR_ANTHROPIC_API_KEY \\"
echo "  --from-literal=github-token=YOUR_GITHUB_TOKEN \\"
echo "  -n default"
echo
echo "# 2. GitHub token secret (may be the same as above)"
echo "kubectl create secret generic github-token-secret \\"
echo "  --from-literal=token=YOUR_GITHUB_TOKEN \\"
echo "  -n default"
echo
echo "# 3. Webhook secret"
echo "kubectl create secret generic example-app-secrets \\"
echo "  --from-literal=webhook-secret=YOUR_WEBHOOK_SECRET \\"
echo "  -n default"
echo
echo "# 4. ECR credentials (if using AWS IAM, may not be needed)"
echo "# kubectl create secret generic ecr-credentials \\"
echo "#   --from-literal=.dockerconfigjson='{}' \\"
echo "#   --type=kubernetes.io/dockerconfigjson \\"
echo "#   -n flux-system"