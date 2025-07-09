#!/bin/bash
set -euo pipefail

# Configuration
NAMESPACE="${NAMESPACE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="claude-runner"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "🚀 Deploying Claude Job to Kubernetes..."

# Get the ECR image URI
ECR_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

# Update the Job manifest with the actual image URI
echo "📝 Updating Job manifest with ECR image URI..."
sed -i.bak "s|PLACEHOLDER_IMAGE_URI|${ECR_IMAGE_URI}|g" infrastructure/apps/base/claude-job.yaml

# Apply the Kubernetes resources
echo "☸️  Applying Kubernetes resources..."
kubectl apply -n ${NAMESPACE} -f infrastructure/apps/base/claude-job.yaml

# Create example ConfigMap and Secret if they don't exist
if ! kubectl get configmap claude-config -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "📋 Creating example ConfigMap..."
  kubectl apply -n ${NAMESPACE} -f infrastructure/apps/base/claude-config-example.yaml
fi

echo "✅ Claude Job deployed successfully!"
echo ""
echo "📊 Check job status with:"
echo "   kubectl get jobs -n ${NAMESPACE} claude-job"
echo "   kubectl logs -n ${NAMESPACE} job/claude-job"