# Webhook Automation for Terragrunt Deployments

This document explains how to use the webhook automation system that replaces GitHub Actions for Terragrunt deployments.

## Overview

The webhook system uses [adnanh/webhook](https://github.com/adnanh/webhook) running on the bastion host to automatically trigger Terragrunt deployments when code is pushed to specific branches.

### Architecture

```
GitHub Push → GitHub Webhook → Bastion Host (webhook server) → Terragrunt → AWS App Runner
```

## Components

### 1. Bastion Host Webhook Server
- **Location**: EC2 instance in public subnet  
- **Port**: 9000
- **Service**: `adnanh/webhook` with systemd service
- **Endpoint**: `http://<bastion-ip>:9000/hooks/terragrunt-deploy`

### 2. Webhook Configuration
- **File**: `/opt/webhook/config/hooks.json`
- **Trigger**: Pushes to `feature/clean-mcp-restructure` branch
- **Security**: HMAC SHA-256 signature verification

### 3. Deployment Script
- **File**: `/opt/webhook/scripts/deploy.sh`
- **Action**: Clones repo, runs `terragrunt apply`, updates App Runner

## Setup Instructions

### Step 1: Deploy Infrastructure
```bash
cd infrastructure/terragrunt/aws/development
terragrunt apply
```

### Step 2: Get Bastion IP and Configure Webhook
```bash
# Get bastion IP from Terragrunt output
BASTION_IP=$(terragrunt output -raw bastion_public_ip)
WEBHOOK_URL=$(terragrunt output -raw webhook_url)

echo "Bastion IP: $BASTION_IP"
echo "Webhook URL: $WEBHOOK_URL"
```

### Step 3: Generate Webhook Secret
```bash
# Generate a secure random secret
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo "Webhook Secret: $WEBHOOK_SECRET"

# Save this secret securely - you'll need it for GitHub configuration
```

### Step 4: Configure Webhook on Bastion
```bash
# Use the provided setup script
./infrastructure/terragrunt/modules/nomad-cluster/aws/webhook-setup.sh $BASTION_IP $WEBHOOK_SECRET
```

### Step 5: Configure GitHub Webhook

1. Go to your GitHub repository settings
2. Navigate to **Settings > Webhooks**
3. Click **Add webhook**
4. Configure:
   - **Payload URL**: `http://<bastion-ip>:9000/hooks/terragrunt-deploy`
   - **Content type**: `application/json`
   - **Secret**: `<your-webhook-secret>`
   - **Events**: Just the push event
   - **Active**: ✅ Checked

## Usage

### Triggering Deployments
Push to the `feature/clean-mcp-restructure` branch:
```bash
git push origin feature/clean-mcp-restructure
```

### Monitoring Deployments
Check deployment logs on the bastion host:
```bash
ssh ec2-user@<bastion-ip>
sudo tail -f /opt/webhook/logs/deployment.log
sudo tail -f /opt/webhook/logs/webhook.log
```

### Checking Webhook Service Status
```bash
ssh ec2-user@<bastion-ip>
sudo systemctl status webhook
```

## Security Features

### 1. HMAC Signature Verification
- GitHub signs payloads with shared secret
- Webhook server verifies signature before execution
- Prevents unauthorized deployment triggers

### 2. Branch Restriction  
- Only pushes to `feature/clean-mcp-restructure` trigger deployments
- Prevents accidental deployments from other branches

### 3. IAM Permissions
- Bastion host has minimal required permissions:
  - Terragrunt/Terraform operations
  - S3 state bucket access
  - DynamoDB state locking
  - App Runner management
  - ECR access

### 4. Network Security
- Webhook port (9000) exposed to internet (required for GitHub)
- SSH access restricted to specified CIDR blocks
- Outbound traffic allowed for deployments

## Troubleshooting

### Webhook Not Triggered
1. Check GitHub webhook delivery status
2. Verify webhook secret matches
3. Check branch name in payload
4. Review webhook service logs

### Deployment Failures
1. Check deployment logs: `/opt/webhook/logs/deployment.log`
2. Verify IAM permissions
3. Check Terragrunt configuration
4. Ensure App Runner image exists in ECR

### Service Issues
```bash
# Restart webhook service
sudo systemctl restart webhook

# Check service status
sudo systemctl status webhook

# View webhook logs
sudo journalctl -u webhook -f
```

## Configuration Files

### hooks.json
```json
[
  {
    "id": "terragrunt-deploy",
    "execute-command": "/opt/webhook/scripts/deploy.sh",
    "trigger-rule": {
      "and": [
        {
          "match": {
            "type": "payload-hmac-sha256",
            "secret": "your-webhook-secret"
          }
        },
        {
          "match": {
            "type": "value", 
            "value": "refs/heads/feature/clean-mcp-restructure"
          }
        }
      ]
    }
  }
]
```

### deploy.sh
- Clones repository to `/tmp/gengine-deploy`
- Checks out specific commit SHA
- Runs `terragrunt apply -auto-approve`
- Logs all operations to `/opt/webhook/logs/deployment.log`

## Monitoring and Logs

### Log Files
- **Webhook Server**: `/opt/webhook/logs/webhook.log`
- **Deployments**: `/opt/webhook/logs/deployment.log`
- **System**: `journalctl -u webhook`

### Log Rotation
- Configured via `/etc/logrotate.d/webhook`
- Daily rotation, 7 days retention
- Automatic compression

## Migration from GitHub Actions

### Benefits
- ✅ No GitHub Actions runner costs
- ✅ Faster deployment (no container startup)
- ✅ Direct access to AWS resources
- ✅ Simplified authentication (IAM roles)
- ✅ Better logging and monitoring

### Considerations
- ⚠️ Webhook endpoint must be publicly accessible
- ⚠️ Requires bastion host maintenance
- ⚠️ Manual secret management

## Extending the System

### Supporting Multiple Branches
Edit `/opt/webhook/config/hooks.json`:
```json
{
  "match": {
    "type": "regex",
    "regex": "refs/heads/(main|develop|feature/.*)"
  }
}
```

### Adding Notifications
Add to deployment script:
```bash
# Slack notification
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Deployment completed for '$COMMIT_SHA'"}' \
  $SLACK_WEBHOOK_URL
```

### Environment-Specific Deployments
- Use branch patterns to determine target environment
- Modify deployment script to run different Terragrunt configurations
- Add environment-specific validation

## Security Best Practices

1. **Rotate webhook secrets regularly**
2. **Monitor webhook access logs**
3. **Restrict GitHub webhook IP ranges** (if possible)
4. **Use least-privilege IAM policies**
5. **Enable CloudTrail for audit logging**
6. **Regular security updates on bastion host**