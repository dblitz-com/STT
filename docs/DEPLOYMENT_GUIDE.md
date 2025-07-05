# 🚀 Production Deployment Guide

This guide walks through deploying the complete GenEngine infrastructure to AWS using Terragrunt and Nomad.

## Prerequisites

### Required Tools
```bash
# Install Terraform
brew install terraform

# Install Terragrunt  
brew install terragrunt

# Install AWS CLI
brew install awscli

# Install Nomad CLI
brew install nomad

# Install Act (for local testing)
brew install act
```

### AWS Account Setup
- AWS account with admin permissions
- AWS CLI configured with credentials
- Domain name registered (or Route53 hosted zone)

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                        │
│  ├── Public Subnets (ALB, NAT Gateway)                    │
│  ├── Private Subnets (Nomad Cluster)                      │
│  └── Database Subnets (Future: RDS/ElastiCache)           │
│                                                            │
│  Nomad Cluster                                             │
│  ├── 3x Server Nodes (t3.medium)                          │
│  ├── 5x Client Nodes (t3.large)                           │
│  ├── Consul Service Discovery                             │
│  ├── Vault Secrets Management                             │
│  └── Service Mesh (Consul Connect)                        │
│                                                            │
│  Application Load Balancer                                 │
│  ├── HTTPS Termination (ACM Certificate)                  │
│  ├── WAF Protection                                        │
│  └── Health Checks                                         │
│                                                            │
│  Services Running on Nomad                                 │
│  ├── GenEngine REST API (Port 8000)                       │
│  ├── Generated MCP Servers (Dynamic ports)                │
│  ├── Prometheus Monitoring                                 │
│  └── Grafana Dashboards                                    │
└─────────────────────────────────────────────────────────────┘
```

## Step 1: Environment Configuration

### 1.1 Copy Environment Templates
```bash
# Copy environment templates
cp .env.local.example .env.production
cp .secrets.local.example .secrets.production

# Copy Terragrunt environment config
cp infrastructure/terragrunt/aws/terragrunt.hcl.example infrastructure/terragrunt/aws/production/terragrunt.hcl
```

### 1.2 Configure AWS Profile
```bash
# Configure AWS credentials for production
aws configure --profile gengine-production
# AWS Access Key ID: [YOUR_AWS_ACCESS_KEY]
# AWS Secret Access Key: [YOUR_AWS_SECRET_KEY] 
# Default region name: us-west-2
# Default output format: json
```

## Step 2: Infrastructure Deployment

### 2.1 Deploy VPC and Networking
```bash
cd infrastructure/terragrunt/aws/production/vpc
terragrunt plan
terragrunt apply
```

### 2.2 Deploy Nomad Cluster
```bash
cd ../nomad-cluster
terragrunt plan
terragrunt apply
```

### 2.3 Deploy Application Load Balancer
```bash
cd ../load-balancer
terragrunt plan 
terragrunt apply
```

## Step 3: Application Deployment

### 3.1 Configure GitHub Actions
```bash
# Set repository secrets in GitHub
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
gh secret set NOMAD_ADDR_PROD --body "https://nomad.yourdomain.com:4646"
gh secret set NOMAD_TOKEN_PROD --body "$NOMAD_PRODUCTION_TOKEN"
```

### 3.2 Deploy REST API Service
```bash
# Push to main branch triggers staging deployment
git checkout main
git push origin main

# Create release for production deployment
gh release create v1.0.0 --title "Production Release v1.0.0"
```

### 3.3 Test Deployment
```bash
# Test health endpoints
curl https://api.yourdomain.com/health
curl https://nomad.yourdomain.com/ui/

# Test MCP server generation
curl -X POST https://api.yourdomain.com/api/v1/convert/git-repo \
  -H "Content-Type: application/json" \
  -d '{"git_url": "https://github.com/example/repo.git"}'
```

## Step 4: Monitoring Setup

### 4.1 Access Monitoring Dashboards
```bash
# Nomad UI
open https://nomad.yourdomain.com/ui/

# Consul UI  
open https://consul.yourdomain.com/ui/

# Prometheus
open https://prometheus.yourdomain.com/

# Grafana
open https://grafana.yourdomain.com/
```

### 4.2 Set Up Alerts
```bash
# Configure Slack webhooks
gh secret set SLACK_WEBHOOK --body "$SLACK_WEBHOOK_URL"

# Test alert notifications
./scripts/test-alerts.sh
```

## Step 5: SSL/TLS and Security

### 5.1 Certificate Management
- Certificates auto-provisioned via AWS Certificate Manager
- Auto-renewal enabled
- HTTP→HTTPS redirects configured

### 5.2 Security Features
- WAF enabled with OWASP rules
- VPC Flow Logs enabled
- CloudTrail logging enabled
- Security Groups with minimal access
- Secrets managed via AWS Parameter Store

## Scaling and Operations

### Auto-Scaling
- Client nodes: 3-20 instances based on CPU/memory
- Automatic scale-out during high load
- Scale-in during low usage periods

### Backup Strategy
- EBS snapshots: Daily, 30-day retention
- Configuration backups to S3
- Database backups (when implemented)

### Update Strategy
- Blue-green deployments for production
- Canary deployments for staging
- Zero-downtime rolling updates

## Troubleshooting

### Common Issues
```bash
# Check Nomad cluster status
nomad node status
nomad server members

# Check service health
nomad job status gengine-rest-api
nomad alloc logs <alloc-id>

# Check load balancer health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check DNS resolution
nslookup api.yourdomain.com
```

### Log Locations
- Application logs: CloudWatch `/aws/nomad/gengine-rest-api`
- Infrastructure logs: CloudWatch `/aws/nomad/cluster`
- Access logs: S3 `gengine-alb-logs-bucket`

## Cost Optimization

### Resource Sizing
- **Development**: ~$200/month
  - 3 t3.small servers, 3 t3.medium clients
- **Production**: ~$800/month  
  - 3 t3.medium servers, 5 t3.large clients
  - ALB, RDS, monitoring

### Cost Controls
- Spot instances for non-critical workloads
- Scheduled scaling (scale down nights/weekends)
- Reserved instances for predictable workloads

## Security Checklist

- [ ] AWS credentials rotated every 90 days
- [ ] Security groups reviewed and minimal
- [ ] SSL certificates auto-renewing
- [ ] WAF rules updated and tested
- [ ] Access logs being monitored
- [ ] Nomad ACLs configured
- [ ] Vault policies implemented
- [ ] CloudTrail enabled across all regions

## Next Steps

1. **Complete this deployment guide**
2. **Provide required credentials and configuration**
3. **Deploy infrastructure using Terragrunt**
4. **Set up GitHub Actions for CI/CD**
5. **Deploy applications to Nomad**
6. **Configure monitoring and alerting**
7. **Test complete end-to-end functionality**