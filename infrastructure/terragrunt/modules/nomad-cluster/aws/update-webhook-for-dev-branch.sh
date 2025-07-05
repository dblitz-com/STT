#!/bin/bash
# Script to update existing webhook configuration to use dev branch
# This updates the bastion host without requiring full infrastructure redeploy

set -e

BASTION_IP="${1:-34.219.243.51}"
KEY_PATH="${2:-$HOME/.ssh/gengine-nomad-dev.pem}"

echo "Updating webhook configuration on bastion host: $BASTION_IP"

# Create updated hooks.json configuration
cat > /tmp/hooks.json << 'EOL'
[
  {
    "id": "terragrunt-deploy",
    "execute-command": "/opt/webhook/scripts/deploy.sh",
    "command-working-directory": "/opt/webhook",
    "response-message": "Deployment triggered successfully",
    "trigger-rule": {
      "and": [
        {
          "match": {
            "type": "payload-hmac-sha256",
            "secret": "WEBHOOK_SECRET_TO_BE_REPLACED",
            "parameter": {
              "source": "header",
              "name": "X-Hub-Signature-256"
            }
          }
        },
        {
          "match": {
            "type": "value",
            "value": "refs/heads/dev",
            "parameter": {
              "source": "payload",
              "name": "ref"
            }
          }
        }
      ]
    },
    "pass-arguments-to-command": [
      {
        "source": "payload",
        "name": "repository.clone_url"
      },
      {
        "source": "payload", 
        "name": "head_commit.id"
      },
      {
        "source": "payload",
        "name": "ref"
      }
    ]
  }
]
EOL

# Create updated deployment script
cat > /tmp/deploy.sh << 'EOL'
#!/bin/bash
set -e

# Arguments from webhook
REPO_URL="$1"
COMMIT_SHA="$2"
REF_NAME="$3"

# Log deployment start
echo "$(date): Starting deployment for commit $COMMIT_SHA from $REF_NAME" >> /opt/webhook/logs/deployment.log

# Set up environment
export AWS_DEFAULT_REGION="us-west-2"
export CLUSTER_NAME="gengine-nomad-dev"

# Clone or update repository first
REPO_DIR="/tmp/gengine-deploy"
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git fetch origin 2>/dev/null || true
    git reset --hard "$COMMIT_SHA" 2>/dev/null || true
else
    git clone "$REPO_URL" "$REPO_DIR" 2>/dev/null || true
    cd "$REPO_DIR"
    git checkout "$COMMIT_SHA" 2>/dev/null || true
fi

# Get GitHub App access token for authentication
ACCESS_TOKEN=$(/opt/webhook/github-app/get-token.sh)
if [ -z "$ACCESS_TOKEN" ]; then
    echo "$(date): Failed to get GitHub App access token" >> /opt/webhook/logs/deployment.log
    exit 1
fi

# Convert GitHub URL to authenticated HTTPS URL
AUTHENTICATED_URL="https://x-access-token:${ACCESS_TOKEN}@github.com/dblitz-com/gengine.git"

# Clone or update repository with proper authentication
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git remote set-url origin "$AUTHENTICATED_URL"
    git fetch origin
    git reset --hard "$COMMIT_SHA"
else
    rm -rf "$REPO_DIR"
    git clone "$AUTHENTICATED_URL" "$REPO_DIR"
    cd "$REPO_DIR"
    git checkout "$COMMIT_SHA"
fi

# Update submodules to latest commits
echo "$(date): Updating git submodules..." >> /opt/webhook/logs/deployment.log
git submodule update --init --recursive --remote >> /opt/webhook/logs/deployment.log 2>&1

# Build and push gengine-rest-api-to-mcp Docker image
echo "$(date): Building gengine-rest-api-to-mcp Docker image..." >> /opt/webhook/logs/deployment.log
cd src/gengines/gengine-rest-api-to-mcp

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
ECR_REPO="gengine-rest-api-to-mcp"
IMAGE_TAG="${COMMIT_SHA:0:7}"

# Login to ECR
echo "$(date): Logging into ECR..." >> /opt/webhook/logs/deployment.log
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names $ECR_REPO --region $AWS_REGION 2>/dev/null || \
    aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION >> /opt/webhook/logs/deployment.log 2>&1

# Build Docker image
echo "$(date): Building Docker image..." >> /opt/webhook/logs/deployment.log
docker build -t $ECR_REPO:$IMAGE_TAG -t $ECR_REPO:latest . >> /opt/webhook/logs/deployment.log 2>&1

# Tag and push to ECR
echo "$(date): Pushing to ECR..." >> /opt/webhook/logs/deployment.log
docker tag $ECR_REPO:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
docker tag $ECR_REPO:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG >> /opt/webhook/logs/deployment.log 2>&1
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest >> /opt/webhook/logs/deployment.log 2>&1

# Navigate back to repository root
cd "$REPO_DIR"

# Navigate to Terragrunt directory
cd infrastructure/terragrunt/aws/development

# Update Terragrunt with new image URI
echo "$(date): Running terragrunt apply for App Runner deployment" >> /opt/webhook/logs/deployment.log
export TF_VAR_app_runner_image_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG"
terragrunt apply -auto-approve >> /opt/webhook/logs/deployment.log 2>&1

# Health check
sleep 30
echo "$(date): Deployment completed" >> /opt/webhook/logs/deployment.log

# Cleanup old repo clones (keep last 3)
find /tmp -name "gengine-deploy-*" -type d -mtime +1 | head -n -3 | xargs rm -rf 2>/dev/null || true

echo "$(date): Deployment finished successfully" >> /opt/webhook/logs/deployment.log
EOL

# Get current webhook secret from bastion
echo "Retrieving current webhook secret..."
WEBHOOK_SECRET=$(ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "sudo grep -o 'secret\": \"[^\"]*' /opt/webhook/config/hooks.json | cut -d'\"' -f3" | tail -1)

if [ -z "$WEBHOOK_SECRET" ] || [ "$WEBHOOK_SECRET" = "WEBHOOK_SECRET_TO_BE_REPLACED" ]; then
    echo "Warning: Could not retrieve webhook secret or it's still the placeholder"
    echo "You may need to manually update the webhook secret in /opt/webhook/config/hooks.json"
else
    echo "Found webhook secret, updating configuration..."
    sed -i.bak "s/WEBHOOK_SECRET_TO_BE_REPLACED/$WEBHOOK_SECRET/g" /tmp/hooks.json
fi

# Copy files to bastion
echo "Copying updated configuration to bastion..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no /tmp/hooks.json ec2-user@$BASTION_IP:/tmp/
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no /tmp/deploy.sh ec2-user@$BASTION_IP:/tmp/

# Apply updates on bastion
echo "Applying updates on bastion..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$BASTION_IP << 'REMOTE_EOF'
    # Backup current configuration
    sudo cp /opt/webhook/config/hooks.json /opt/webhook/config/hooks.json.backup
    sudo cp /opt/webhook/scripts/deploy.sh /opt/webhook/scripts/deploy.sh.backup
    
    # Apply new configuration
    sudo mv /tmp/hooks.json /opt/webhook/config/hooks.json
    sudo mv /tmp/deploy.sh /opt/webhook/scripts/deploy.sh
    
    # Set proper permissions
    sudo chown webhook:webhook /opt/webhook/config/hooks.json
    sudo chown webhook:webhook /opt/webhook/scripts/deploy.sh
    sudo chmod +x /opt/webhook/scripts/deploy.sh
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker webhook
        sudo usermod -a -G docker ec2-user
    fi
    
    # Restart webhook service
    sudo systemctl restart webhook
    
    echo "Webhook service updated successfully!"
    sudo systemctl status webhook
REMOTE_EOF

# Clean up temporary files
rm -f /tmp/hooks.json /tmp/deploy.sh

echo ""
echo "Webhook configuration updated successfully!"
echo "The webhook will now trigger on pushes to the 'dev' branch"
echo ""
echo "Next steps:"
echo "1. Update the GitHub webhook to trigger on the 'dev' branch"
echo "2. Push to the 'dev' branch to test the deployment"