#!/bin/bash
set -euo pipefail

# Test script for Claude Kubernetes execution
NAMESPACE="${NAMESPACE:-default}"

echo "🧪 Testing Claude execution in Kubernetes..."

# Clean up any existing test resources
echo "🧹 Cleaning up existing test resources..."
kubectl delete job claude-job -n ${NAMESPACE} --ignore-not-found=true
kubectl delete configmap claude-test-config -n ${NAMESPACE} --ignore-not-found=true

# Create a simple MCP config for testing
cat > /tmp/test-mcp-config.json <<EOF
{
  "mcpServers": {}
}
EOF

# Create test ConfigMap
echo "📋 Creating test ConfigMap..."
kubectl create configmap claude-test-config -n ${NAMESPACE} \
  --from-literal=job_id="test-$(date +%s)" \
  --from-literal=comment_id="test-comment" \
  --from-literal=github_repository="anthropics/claude-code" \
  --from-literal=github_ref="main" \
  --from-literal=allowed_tools="Read,LS" \
  --from-literal=max_turns="1" \
  --from-literal=timeout_minutes="5" \
  --from-literal=prompt="List the files in the current directory and read the README.md file if it exists." \
  --from-file=mcp_config=/tmp/test-mcp-config.json

# Apply the Job with test config
echo "🚀 Creating Claude test job..."
cat infrastructure/apps/base/claude-job.yaml | \
  sed 's/claude-config/claude-test-config/g' | \
  kubectl apply -n ${NAMESPACE} -f -

# Wait for job to start
echo "⏳ Waiting for job to start..."
sleep 5

# Watch the job progress
echo "👀 Monitoring job progress..."
kubectl wait --for=condition=complete --timeout=300s -n ${NAMESPACE} job/claude-job || \
  kubectl wait --for=condition=failed --timeout=300s -n ${NAMESPACE} job/claude-job || true

# Show logs
echo ""
echo "📜 Job logs:"
kubectl logs -n ${NAMESPACE} job/claude-job --tail=100

# Check job status
echo ""
echo "📊 Job status:"
kubectl get job claude-job -n ${NAMESPACE} -o wide

# Clean up
echo ""
read -p "🗑️  Clean up test resources? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  kubectl delete job claude-job -n ${NAMESPACE}
  kubectl delete configmap claude-test-config -n ${NAMESPACE}
  rm -f /tmp/test-mcp-config.json
  echo "✅ Test resources cleaned up"
fi