#!/bin/bash
set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="claude-runner"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "🚀 Building Claude Runner Docker image..."

# Get ECR login token
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Create ECR repository if it doesn't exist
echo "📦 Ensuring ECR repository exists..."
aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} 2>/dev/null || \
  aws ecr create-repository --repository-name ${ECR_REPOSITORY} --region ${AWS_REGION}

# Define ECR image URI
ECR_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

# Setup Docker buildx for multi-platform builds
echo "🔧 Setting up Docker buildx..."
docker buildx create --use --name claude-builder || docker buildx use claude-builder

# Build the Docker image for amd64 platform and push to ECR
echo "🔨 Building Docker image for amd64 platform and pushing to ECR..."
docker buildx build --platform linux/amd64 -f Dockerfile.claude-runner -t ${ECR_IMAGE_URI} --push .

echo "✅ Docker image pushed successfully: ${ECR_IMAGE_URI}"
echo ""
echo "📝 Update the Kubernetes Job manifest with this image URI:"
echo "   ${ECR_IMAGE_URI}"