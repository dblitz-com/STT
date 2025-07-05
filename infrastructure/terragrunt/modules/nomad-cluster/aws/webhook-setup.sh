#!/bin/bash
# Webhook Setup Script
# Run this script after Terragrunt deployment to configure webhook secrets

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <bastion-public-ip> <webhook-secret>"
    echo "Example: $0 54.123.45.67 your-secure-random-secret-here"
    exit 1
fi

BASTION_IP="$1"
WEBHOOK_SECRET="$2"

echo "Setting up webhook configuration on bastion host $BASTION_IP..."

# Update webhook configuration with the secret
ssh -o StrictHostKeyChecking=no ec2-user@$BASTION_IP << EOF
sudo sed -i 's/WEBHOOK_SECRET_TO_BE_REPLACED/$WEBHOOK_SECRET/g' /opt/webhook/config/hooks.json
sudo systemctl restart webhook
sudo systemctl status webhook
EOF

echo "Webhook configuration updated successfully!"
echo ""
echo "Next steps:"
echo "1. Go to your GitHub repository settings"
echo "2. Navigate to Settings > Webhooks"
echo "3. Click 'Add webhook'"
echo "4. Set Payload URL to: http://$BASTION_IP:9000/hooks/terragrunt-deploy"
echo "5. Set Content type to: application/json"
echo "6. Set Secret to: $WEBHOOK_SECRET"
echo "7. Select 'Just the push event'"
echo "8. Ensure 'Active' is checked"
echo "9. Click 'Add webhook'"
echo ""
echo "Test the webhook by pushing to the feature/clean-mcp-restructure branch"