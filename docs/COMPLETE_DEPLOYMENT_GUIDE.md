# Complete GenEngine Deployment Guide

## Overview

This guide walks through deploying the complete GenEngine infrastructure to AWS using our Nomad cluster, Terragrunt infrastructure-as-code, and GitHub Actions CI/CD pipeline.

## Architecture Summary

- **Main Repository**: Houses the engine with Git submodules for individual gengines
- **Submodules**: `gengine-rest-api-to-mcp` and `gengine-mcp-catalog` 
- **Container Orchestration**: HashiCorp Nomad cluster on AWS EC2
- **Infrastructure**: Terraform/Terragrunt for cloud-agnostic deployment
- **CI/CD**: GitHub Actions with automated testing, building, and deployment
- **Service Mesh**: Consul Connect for secure service communication
- **Monitoring**: Prometheus + Grafana stack

## Prerequisites

### 1. Local Development Setup

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/your-org/engine.git
cd engine

# Install dependencies
npm install  # or yarn install

# Test that everything works locally
docker-compose up
```

### 2. Required Tools

```bash
# Install required CLI tools
brew install terraform terragrunt awscli gh  # macOS
# or
apt-get install terraform terragrunt awscli gh  # Linux
```

### 3. AWS Account Setup

1. **AWS Account**: Ensure you have an AWS account with appropriate permissions
2. **AWS CLI**: Configure with `aws configure`
3. **Domain Name**: Register a domain or have access to Route53 hosted zone

## Step 1: AWS Prerequisites Setup

Run our automated setup script:

```bash
# Make script executable (already done)
chmod +x scripts/aws-prerequisites.sh

# Run the setup
./scripts/aws-prerequisites.sh
```

This script creates:
- S3 buckets for Terraform state (per environment)
- DynamoDB tables for state locking
- IAM roles with necessary permissions
- EC2 key pairs for SSH access
- Validates all resources

## Step 2: Configure Environment Variables

```bash
# Copy the template
cp .env.template .env

# Edit with your values
vim .env  # or your preferred editor
```

Required values:
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- `PRODUCTION_DOMAIN`, `STAGING_DOMAIN`, `DEVELOPMENT_DOMAIN`
- `ROUTE53_ZONE_ID` (find with: `aws route53 list-hosted-zones`)
- `GITHUB_TOKEN` (for GitHub Actions)

## Step 3: Update Terragrunt Configurations

Update the domain and Route53 configuration in each environment:

```bash
# Production
vim infrastructure/terragrunt/aws/env-config/production.hcl
# Update domain_name and route53_zone_id

# Staging  
vim infrastructure/terragrunt/aws/env-config/staging.hcl
# Update domain_name and route53_zone_id

# Development
vim infrastructure/terragrunt/aws/env-config/development.hcl  
# Update domain_name and route53_zone_id
```

## Step 4: Deploy Infrastructure

### Development Environment (Start Here)

```bash
cd infrastructure/terragrunt/aws/development

# Plan the deployment
terragrunt plan

# Apply the infrastructure
terragrunt apply
```

Wait for deployment (10-15 minutes). The script will output:
- Nomad cluster endpoints
- Load balancer DNS names
- SSH commands for accessing nodes

### Staging Environment

```bash
cd ../staging
terragrunt plan
terragrunt apply
```

### Production Environment

```bash
cd ../production
terragrunt plan
terragrunt apply
```

## Step 5: Configure GitHub Actions

Set up repository secrets:

```bash
# Using GitHub CLI
gh secret set AWS_ACCESS_KEY_ID -b"your_access_key"
gh secret set AWS_SECRET_ACCESS_KEY -b"your_secret_key"  
gh secret set AWS_REGION -b"us-west-2"
gh secret set PERPLEXITY_API_KEY -b"your_perplexity_key"

# Or manually via GitHub web interface:
# Go to repo Settings > Secrets and variables > Actions
```

## Step 6: Test the Pipeline

```bash
# Create a test branch
git checkout -b test-deployment

# Make a small change
echo "# Test" >> README.md
git add README.md
git commit -m "Test deployment pipeline"

# Push to trigger pipeline
git push origin test-deployment

# Create pull request
gh pr create --title "Test Deployment" --body "Testing the complete pipeline"
```

Monitor the GitHub Actions workflow to ensure:
- ✅ Submodules are checked out correctly
- ✅ Tests pass for main repo and all submodules
- ✅ Docker images build successfully
- ✅ Security scans pass
- ✅ Deployment to development environment succeeds

## Step 7: Deploy Applications

Once infrastructure is ready, deploy the applications:

```bash
# The GitHub Actions pipeline will automatically deploy on:
# - Push to main branch → Development environment
# - PR merge to main → Staging environment (with approval)
# - Manual trigger → Production environment (with approval)
```

## Step 8: Verify Deployment

### Check Nomad Cluster

```bash
# SSH to Nomad server (get IP from Terragrunt output)
ssh -i keys/gengine-dev-keypair.pem ec2-user@<nomad-server-ip>

# Check cluster status
nomad node status
nomad job status

# Check services
consul catalog services
```

### Test API Endpoints

```bash
# Test REST API (replace with your domain)
curl https://dev.gengine.yourcompany.com/api/health

# Test MCP catalog
curl https://dev.gengine.yourcompany.com/api/v1/servers

# Convert a repository to MCP
curl -X POST https://dev.gengine.yourcompany.com/api/v1/convert-git-repo \
  -H "Content-Type: application/json" \
  -d '{"git_url": "https://github.com/example/repo.git"}'
```

### Check Monitoring

Access Grafana dashboard:
```
https://grafana.dev.gengine.yourcompany.com
```

Default credentials (change immediately):
- Username: `admin`
- Password: Check Terraform output or AWS Secrets Manager

## Git Submodules in Production

Our deployment strategy handles Git submodules as follows:

### 1. Automated Submodule Management
- GitHub Actions automatically checks out all submodules recursively
- Docker builds include all submodule code (no runtime Git operations)
- Version tags are synchronized across main repo and all submodules

### 2. Deployment Process
```
1. Developer commits to submodule
2. CI/CD tests submodule independently  
3. Main repo is updated to point to new submodule commit
4. Main repo CI/CD tests integration
5. Docker images are built with all submodule code baked in
6. Images are deployed to Nomad cluster
```

### 3. Rollback Strategy
- Each deployment creates immutable Docker images
- Nomad can quickly rollback to previous image versions
- Git submodule pointers can be reverted if needed

## Scaling and Optimization

### Auto-Scaling
The Nomad cluster includes auto-scaling:
- **Development**: 2-3 client nodes
- **Staging**: 2-6 client nodes  
- **Production**: 3-20 client nodes

### Performance Monitoring
- Prometheus collects metrics from all services
- Grafana dashboards show cluster health and application performance
- Alerts are configured for critical issues

### Cost Optimization
- Development environment auto-shuts down after hours
- Spot instances used for non-critical workloads
- Monitoring tracks resource utilization

## Troubleshooting

### Common Issues

#### 1. Submodule Checkout Fails
```bash
# Manually update submodules
git submodule update --init --recursive --remote

# Check submodule URLs
cat .gitmodules
```

#### 2. Docker Build Fails
```bash
# Test Docker build locally
docker build -t test-image src/gengines/gengine-rest-api-to-mcp/

# Check for file permission issues
ls -la src/gengines/*/
```

#### 3. Terragrunt Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terragrunt syntax
terragrunt validate

# Check for state lock issues
terragrunt force-unlock <lock-id>
```

#### 4. Nomad Jobs Fail to Start
```bash
# SSH to Nomad server
ssh -i keys/gengine-dev-keypair.pem ec2-user@<server-ip>

# Check job status
nomad job status gengine-rest-api

# View logs
nomad alloc logs <allocation-id>
```

### Getting Help

1. **Logs**: Check CloudWatch logs for detailed error messages
2. **Monitoring**: Use Grafana dashboards to identify performance issues
3. **Documentation**: Refer to component-specific READMEs
4. **Community**: HashiCorp Nomad and Terraform communities

## Security Considerations

### 1. Access Control
- IAM roles with minimal required permissions
- Security groups restrict network access
- SSH keys for emergency access only

### 2. Secrets Management
- Vault integration for production secrets
- GitHub Actions secrets for CI/CD
- Environment variables for application configuration

### 3. Network Security
- VPC with private subnets for Nomad clients
- Application Load Balancer with SSL termination
- WAF rules for additional protection

### 4. Monitoring and Auditing
- CloudTrail for API audit logging
- VPC Flow Logs for network monitoring
- Application-level security scanning in CI/CD

## Next Steps

1. **Custom Domain**: Configure your actual domain names
2. **SSL Certificates**: Set up custom SSL certificates if needed
3. **Monitoring**: Configure additional alerts and dashboards
4. **Backup**: Implement backup strategies for stateful services
5. **DR**: Plan disaster recovery procedures

## Support and Maintenance

### Regular Tasks
- Monitor cluster health via Grafana
- Update dependencies via Dependabot PRs
- Review security alerts and patches
- Scale cluster based on usage patterns

### Upgrades
- Nomad cluster upgrades via rolling deployments
- Application updates via CI/CD pipeline
- Infrastructure updates via Terragrunt

This deployment guide ensures a production-ready, secure, and scalable infrastructure for the GenEngine project with proper Git submodule handling throughout the entire development and deployment lifecycle.