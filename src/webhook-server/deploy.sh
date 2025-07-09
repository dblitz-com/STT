#!/bin/bash
# Deploy Agentic Coding Webhook Server

set -e

echo "🚀 Deploying Agentic Coding Webhook Server..."

# Configuration
BASTION_HOST="ec2-user@34.219.243.51"
DEPLOY_DIR="/opt/webhook"
SERVICE_NAME="agentic-webhook"

# Build and package
echo "📦 Building webhook server..."
bun install
bun build simple-index.ts --outdir=dist --target=node

# Create deployment package
echo "📋 Creating deployment package..."
tar -czf webhook-server.tar.gz dist/ package.json

# Copy to bastion host
echo "📤 Copying to bastion host..."
scp webhook-server.tar.gz ${BASTION_HOST}:/tmp/

# Deploy on bastion host
echo "🔧 Installing on bastion host..."
ssh ${BASTION_HOST} << 'EOF'
set -e

# Stop existing service if running
sudo systemctl stop agentic-webhook || true

# Create deploy directory
sudo mkdir -p /opt/webhook
cd /opt/webhook

# Extract new version
sudo tar -xzf /tmp/webhook-server.tar.gz

# Install dependencies if needed
if command -v npm >/dev/null 2>&1; then
    sudo npm install --production
fi

# Set permissions
sudo chown -R ec2-user:ec2-user /opt/webhook

# Create systemd service
sudo tee /etc/systemd/system/agentic-webhook.service > /dev/null << 'SERVICE'
[Unit]
Description=Agentic Coding Webhook Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/webhook
ExecStart=/usr/bin/node dist/simple-index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=9000
Environment=WEBHOOK_SECRET=bb2a9a1d476c3a69ff52fb2a3503bb8c339eb068c11e81f19b8754b18c3c4fa6
EnvironmentFile=-/opt/webhook/.env

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=agentic-webhook

[Install]
WantedBy=multi-user.target
SERVICE

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable agentic-webhook
sudo systemctl start agentic-webhook

echo "✅ Webhook server deployed and started"
echo "📊 Service status:"
sudo systemctl status agentic-webhook --no-pager -l

echo "📝 Logs:"
sudo journalctl -u agentic-webhook --no-pager -l --since "5 minutes ago"
EOF

echo "🎉 Deployment complete!"
echo ""
echo "🔗 Test endpoints:"
echo "   Health: http://34.219.243.51:9000/health"
echo "   Status: http://34.219.243.51:9000/status"
echo ""
echo "🧪 Test with:"
echo "   ./test-issue-webhook.sh"
echo ""
echo "📊 Monitor logs:"
echo "   ssh ec2-user@34.219.243.51 'sudo journalctl -u agentic-webhook -f'"