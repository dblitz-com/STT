#!/bin/bash
# Script to create AWS credentials secret for Terraform controller

# Try to use .env file first
if [ -f "/Users/devin/dblitz/engine/.env" ]; then
    echo "Loading AWS credentials from .env file..."
    source /Users/devin/dblitz/engine/.env
fi

# If not in .env, use AWS CLI credentials
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Getting AWS credentials from AWS CLI..."
    AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
    AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
    AWS_REGION=$(aws configure get region)
fi

# Default region if not set
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
fi

# Create the secret
kubectl create secret generic aws-credentials \
  --namespace=tf-system \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_REGION="$AWS_REGION" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "AWS credentials secret created/updated in tf-system namespace"