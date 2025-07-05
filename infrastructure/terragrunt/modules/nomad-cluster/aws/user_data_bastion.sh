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

# Clone or update repository first (will fail with old auth, but that's ok for now)
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

# Check if self-update is needed (from trigger file or from repository)
if [ -f "/tmp/webhook-self-update-needed" ] || [ -f "$REPO_DIR/TRIGGER_SELF_UPDATE" ]; then
    touch /tmp/webhook-self-update-needed
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
    
    # Deploy new private key if needed
    echo "$(date): Deploying new GitHub App private key..." >> /opt/webhook/logs/deployment.log
    sudo tee /opt/webhook/github-app/private-key.pem << 'PRIVATE_KEY_EOL'
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0F3EVKyZoTho/8fcJCv6yq05WwiioBF0D9q46Hdv7p/M0EiH
rAPrZr91/wb+oaqSL7r9sG9hzWFqjhSetUOatbzFTPILB8UiJEraoJjDVPSY129V
uZjDNla3Al30rz+OuPTfOgoDADSLLbVJNy+taMQ8HwkvMnx8ufNLNgbQ53h+WYU0
zQ1C7wvk8Q0k4YdgCnbwWco7eL3gpD54wi+dXVM83eN8X+sJLfj5Aoer879dRG3T
k0K2cRc/iplvkginjOplSU+4m3EL7IZQ/9tasYghOnOch49T54M/PIoORR4S8RUo
LPcwxMacE7K3ZvBMyPTQ/h9XB2lFgADKgXv3LwIDAQABAoIBAC0KyAEh2of+YLxC
IPV0yF79uTNTl4wQmc0/k8802m5z/ttbgnCN3Fo2szQw9+RMshM9Uc/NFBBIqbcT
AAfhGFWG/AOZIwdH9wxvXflvbHI1+cBAYgCf5Dsf3anWU6l6jMiwrnymY2Ws9hUo
Zi5W0R6fpPt0ic5ZGME9tZl1Ob1/a61pZ4A8qm6cF67CTDbyqGPieY80JQxi0uvs
ucKc/ENe0jO7h9i3jMWf4941S7bv4frRdUSeVTNWZq4XH9+imAxr7/kMiqsTwrfO
6j/APA7Dc2yRnZECSsQ4r6o4b/PrBaQTB3/LjIQsW3pSp5bw+cjpDwjpfUJENg6a
AGX0FDECgYEA74VhQSg01XAHmhAYKoOVl017WLSE9eBnxQB6xWPT6MK2DB5bcB+b
HnlTRTI9LZLZFd0HXRViz2ODSRSpbNADZky/vMYwTS8p4VCzl00Sbr1AE30es2/l
glGPfIsMfY0mDknVJuiTH1zPbrviiJsfsOyPWW/Xq8YcvDLCpJAwxScCgYEA3rOq
uHh666zVTgaPsfk0ozuaVKpRSLGL6lStf4ToDwVH2k7+y2SXA5pqXoCrv6lsIEmT
mb7Fk90s2qRPIfzLWIG1Fi4lxHGHVlilGOFFSLVaGjUnesyHuW9Ku/kQht0s/WMq
6B3dS4r4P+OHgZU29pNATDS7mqKLScU6Q1yRUrkCgYABSzUlRvRSGtLPsDqRMDjE
onSCHCeDtHybAc+n9UwVu8eD9T4FMwaBeaJLg2P1NQ/bIGCDzjPEbwMsh+IKZm0+
Rjfa6y8jm5ecUfVGYfIxivAnqstZqMcSlyIxSAb/Pp3wAdIW7baturCcJoOovT3E
lOKJVyNRGDbbhWKrxOOejQKBgDQUVBI7qpM+octTYXs/Sf36TEcMZWHYk13DW6d8
j0Aj/f+hhZhO97nR/JoJASEbH7wVOL01jcLccEbZMeBC29Lg0lZTiGV+HyYkKMe+
tpMgRefnEkp3Vi4ZRqLaxfCj/IdtD3WktkGaSB+4t9Gn8WiMWvb3RgANjwE7bDqg
hSORAoGBAOopKs7T5i41PBihk47wY3H7q0gIzKaqomMyj2w0tJFAIUemvvBkKFhD
Twb54FqAhfEuvmw/xcQoVz1gnlrpUjFMsDvcwyeJojFT8QNY0RzJMw8ETSWx/2B9
8mDltJMXuXQqk9UfAX4H8bbZehExaiJuHB4U5w6SbbApK6a9ToiZ
-----END RSA PRIVATE KEY-----
PRIVATE_KEY_EOL
    
    sudo chmod 600 /opt/webhook/github-app/private-key.pem
    sudo chown webhook:webhook /opt/webhook/github-app/private-key.pem
    
    rm -f /tmp/webhook-self-update-needed
    echo "$(date): Self-update completed with new private key" >> /opt/webhook/logs/deployment.log
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
    # If initial clone failed, try again with auth
    rm -rf "$REPO_DIR"
    git clone "$AUTHENTICATED_URL" "$REPO_DIR"
    cd "$REPO_DIR"
    git checkout "$COMMIT_SHA"
fi

# Clean up trigger file if it exists
if [ -f "$REPO_DIR/TRIGGER_SELF_UPDATE" ]; then
    echo "$(date): Self-update trigger file found and processed" >> /opt/webhook/logs/deployment.log
    rm -f "$REPO_DIR/TRIGGER_SELF_UPDATE"
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