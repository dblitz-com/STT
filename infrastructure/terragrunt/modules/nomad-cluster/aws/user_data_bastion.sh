#!/bin/bash
set -e

# Variables from Terraform
CLUSTER_NAME="${cluster_name}"
REGION="${region}"

# System update and basic packages
yum update -y
yum install -y amazon-ssm-agent wget unzip git jq

# Enable and start SSM agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install Terragrunt
TERRAGRUNT_VERSION="0.55.1"
wget "https://github.com/gruntwork-io/terragrunt/releases/download/v$${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
chmod +x terragrunt_linux_amd64
mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Install Terraform
TERRAFORM_VERSION="1.6.6"
wget "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
unzip "terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
chmod +x terraform
mv terraform /usr/local/bin/
rm "terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"

# Install webhook
WEBHOOK_VERSION="2.8.1"
wget "https://github.com/adnanh/webhook/releases/download/$${WEBHOOK_VERSION}/webhook-linux-amd64.tar.gz"
tar -xvf webhook-linux-amd64.tar.gz
chmod +x webhook-linux-amd64/webhook
mv webhook-linux-amd64/webhook /usr/local/bin/
rm -rf webhook-linux-amd64*

# Create webhook user and directories
useradd -r -s /bin/bash webhook
mkdir -p /opt/webhook/{config,scripts,logs}
chown -R webhook:webhook /opt/webhook

# Create webhook configuration directory
cat > /opt/webhook/config/hooks.json << 'EOL'
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
            "value": "refs/heads/feature/clean-mcp-restructure",
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

# Create deployment script
cat > /opt/webhook/scripts/deploy.sh << 'EOL'
#!/bin/bash
set -e

# Arguments from webhook
REPO_URL="$1"
COMMIT_SHA="$2"
REF_NAME="$3"

# Log deployment start
echo "$(date): Starting deployment for commit $COMMIT_SHA from $REF_NAME" >> /opt/webhook/logs/deployment.log

# Set up environment
export AWS_DEFAULT_REGION="${region}"
export CLUSTER_NAME="${cluster_name}"

# Check if self-update is needed
if [ -f "/tmp/webhook-self-update-needed" ]; then
    echo "$(date): Running webhook self-update..." >> /opt/webhook/logs/deployment.log
    # Update GitHub App token generation script
    sudo tee /opt/webhook/github-app/get-token.sh << 'SELF_UPDATE_EOL'
#!/bin/bash
# GitHub App Token Generation Script (Fixed)
# Uses direct installation ID instead of repository lookup

set -e

APP_ID="1529272"
INSTALLATION_ID="74523281"  # dblitz-com org installation ID
PRIVATE_KEY_PATH="/opt/webhook/github-app/private-key.pem"

# Generate JWT for GitHub App authentication
generate_jwt() {
    local header='{"alg":"RS256","typ":"JWT"}'
    local now=$(date +%s)
    local iat=$((now - 60))
    local exp=$((now + 600))
    
    local payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${APP_ID}\"}"
    
    local header_b64=$(echo -n "$header" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    local payload_b64=$(echo -n "$payload" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    local signature_input="${header_b64}.${payload_b64}"
    local signature=$(echo -n "$signature_input" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    echo "${header_b64}.${payload_b64}.${signature}"
}

# Get installation access token using direct installation ID
get_installation_token() {
    local jwt=$(generate_jwt)
    
    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")
    
    echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4
}

# Main execution
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "Error: Private key not found at $PRIVATE_KEY_PATH" >&2
    exit 1
fi

ACCESS_TOKEN=$(get_installation_token)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to get access token" >&2
    exit 1
fi

echo "$ACCESS_TOKEN"
SELF_UPDATE_EOL
    
    sudo chmod +x /opt/webhook/github-app/get-token.sh
    rm -f /tmp/webhook-self-update-needed
    echo "$(date): Self-update completed" >> /opt/webhook/logs/deployment.log
fi

# Get GitHub App access token for authentication
ACCESS_TOKEN=$(/opt/webhook/github-app/get-token.sh)
if [ -z "$ACCESS_TOKEN" ]; then
    echo "$(date): Failed to get GitHub App access token" >> /opt/webhook/logs/deployment.log
    exit 1
fi

# Convert GitHub URL to authenticated HTTPS URL
AUTHENTICATED_URL="https://x-access-token:${ACCESS_TOKEN}@github.com/dblitz-com/gengine.git"

# Clone or update repository
REPO_DIR="/tmp/gengine-deploy"
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git remote set-url origin "$AUTHENTICATED_URL"
    git fetch origin
    git reset --hard "$COMMIT_SHA"
else
    git clone "$AUTHENTICATED_URL" "$REPO_DIR"
    cd "$REPO_DIR"
    git checkout "$COMMIT_SHA"
fi

# Navigate to Terragrunt directory
cd infrastructure/terragrunt/aws/development

# Run Terragrunt deployment
echo "$(date): Running terragrunt apply for App Runner deployment" >> /opt/webhook/logs/deployment.log
terragrunt apply -auto-approve >> /opt/webhook/logs/deployment.log 2>&1

# Health check
sleep 30
echo "$(date): Deployment completed" >> /opt/webhook/logs/deployment.log

# Cleanup old repo clones (keep last 3)
find /tmp -name "gengine-deploy-*" -type d -mtime +1 | head -n -3 | xargs rm -rf 2>/dev/null || true

echo "$(date): Deployment finished successfully" >> /opt/webhook/logs/deployment.log
EOL

# Make scripts executable
chmod +x /opt/webhook/scripts/deploy.sh
chown -R webhook:webhook /opt/webhook

# Create systemd service for webhook
cat > /etc/systemd/system/webhook.service << 'EOL'
[Unit]
Description=Webhook Server
After=network.target

[Service]
Type=simple
User=webhook
Group=webhook
WorkingDirectory=/opt/webhook
ExecStart=/usr/local/bin/webhook -hooks /opt/webhook/config/hooks.json -port 9000 -verbose -logfile /opt/webhook/logs/webhook.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Enable and start webhook service
systemctl daemon-reload
systemctl enable webhook
systemctl start webhook

# Configure log rotation
cat > /etc/logrotate.d/webhook << 'EOL'
/opt/webhook/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 webhook webhook
    postrotate
        systemctl reload webhook
    endscript
}
EOL

# Set up AWS CLI for the webhook user
sudo -u webhook aws configure set region ${region}

echo "Bastion webhook server setup completed"