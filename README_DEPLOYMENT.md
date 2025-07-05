# 🚀 GenEngine - Production Deployment

**One-Click Multi-Cloud Deployment with Automated Credential Generation**

## Quick Start (3 Steps)

### 1. 🔐 Generate Cloud Credentials
```bash
# For AWS (recommended for beginners)
./scripts/setup-cloud-credentials.sh aws

# For Google Cloud
./scripts/setup-cloud-credentials.sh gcp

# For Azure
./scripts/setup-cloud-credentials.sh azure

# For all clouds (maximum flexibility)
./scripts/setup-cloud-credentials.sh all

# Interactive mode (choose your cloud)
./scripts/setup-cloud-credentials.sh
```

### 2. 🔧 Configure Your Domain
Update your `.env` file with your domain:
```bash
# Edit these values in .env
PRODUCTION_DOMAIN=api.yourcompany.com
STAGING_DOMAIN=staging-api.yourcompany.com
DEVELOPMENT_DOMAIN=dev-api.yourcompany.com
ROUTE53_ZONE_ID=Z1234567890ABC  # For AWS
```

### 3. 🚀 Deploy Infrastructure
```bash
# AWS
./scripts/aws-prerequisites.sh
cd infrastructure/terragrunt/aws/development
terragrunt apply

# Google Cloud
gsutil mb gs://your-project-terraform-state-dev
cd infrastructure/terragrunt/gcp/development  
terragrunt apply

# Azure
cd infrastructure/terragrunt/azure/development
terragrunt apply
```

## What You Get

### ✅ Complete Production Infrastructure
- **Container Orchestration**: HashiCorp Nomad cluster
- **Service Mesh**: Consul Connect for secure communication
- **Load Balancing**: Cloud-native load balancers with SSL
- **Monitoring**: Prometheus + Grafana stack
- **Auto-scaling**: Intelligent scaling based on demand
- **Multi-environment**: Development, staging, production

### ✅ Automated CI/CD Pipeline
- **GitHub Actions**: Fully configured workflows
- **Git Submodules**: Proper handling and versioning
- **Security Scanning**: Container and dependency scanning
- **Multi-stage Deployment**: Safe rollouts with approvals
- **Rollback**: Quick rollback on failures

### ✅ Git Submodules Strategy
- **Automated Checkout**: Recursive submodule handling
- **Docker Integration**: All code baked into containers
- **Version Synchronization**: Coordinated tagging across repos
- **Testing**: Individual and integration testing

## Architecture

```
┌─ Main Repository (engine)
│  ├─ 📁 src/gengines/
│  │  ├─ 🔗 gengine-rest-api-to-mcp  (submodule)
│  │  └─ 🔗 gengine-mcp-catalog      (submodule)
│  ├─ 🐳 Docker containers with all submodule code
│  ├─ ☁️  Deployed to Nomad cluster
│  └─ 🔄 CI/CD pipeline handles everything
```

## Multi-Cloud Support

| Feature | AWS | Google Cloud | Azure |
|---------|-----|--------------|-------|
| **Auto Credentials** | ✅ | ✅ | ✅ |
| **Infrastructure** | ✅ | ✅ | ✅ |
| **Container Orchestration** | Nomad on EC2 | Nomad on Compute Engine | Nomad on Virtual Machines |
| **Load Balancer** | ALB | Cloud Load Balancer | Application Gateway |
| **DNS** | Route53 | Cloud DNS | Azure DNS |
| **Storage** | S3 + EBS | Cloud Storage + Persistent Disk | Storage Account + Managed Disks |
| **Monitoring** | CloudWatch | Cloud Monitoring | Azure Monitor |

## Scripts Overview

### 🔐 Credential Generation
- **`setup-cloud-credentials.sh`** - Master script (choose your cloud)
- **`generate-aws-credentials.sh`** - AWS IAM user + access keys
- **`generate-gcp-credentials.sh`** - GCP service account + key
- **`generate-azure-credentials.sh`** - Azure service principal + secrets

### 🏗️ Infrastructure Setup
- **`aws-prerequisites.sh`** - S3 buckets, DynamoDB, IAM roles
- **Terragrunt configs** - Environment-specific infrastructure

### 🔧 Generated Files
```
credentials/
├── aws-credentials.env      # AWS access keys
├── gcp-service-account.json # GCP service account key  
├── gcp-credentials.env      # GCP configuration
└── azure-credentials.env   # Azure service principal

keys/
├── gengine-dev-keypair.pem     # SSH keys for development
├── gengine-staging-keypair.pem # SSH keys for staging
└── gengine-production-keypair.pem # SSH keys for production
```

## Security Features

### 🛡️ Built-in Security
- **IAM Least Privilege**: Minimal required permissions
- **Encrypted Storage**: All data encrypted at rest
- **Network Security**: VPC, security groups, firewalls
- **Secrets Management**: Vault integration for production
- **SSL/TLS**: Automatic certificate management
- **WAF Protection**: Web application firewall (production)

### 🔒 Credential Management
- **Auto-rotation**: Scripts support credential refresh
- **GitHub Secrets**: Automatic CI/CD secret configuration
- **Local Security**: Credentials excluded from Git
- **Multi-factor**: Supports MFA-enabled accounts

## Cost Optimization

### 💰 Development Environment
- **Auto-shutdown**: Instances stop after hours
- **Minimal sizing**: t3.micro/small instances
- **Single AZ**: Reduced networking costs
- **Spot instances**: Where appropriate

### 💰 Production Environment
- **Auto-scaling**: Scale down during low usage
- **Reserved instances**: For predictable workloads
- **Efficient routing**: Optimized traffic patterns
- **Resource monitoring**: Cost alerts and optimization

## Troubleshooting

### Common Issues

#### 🔧 Credential Generation Fails
```bash
# Check CLI authentication
aws sts get-caller-identity
gcloud auth list
az account show

# Re-authenticate if needed
aws configure
gcloud auth login
az login
```

#### 🔧 Terragrunt Apply Fails
```bash
# Check credentials and permissions
terragrunt validate
terragrunt plan

# Force unlock if state is locked
terragrunt force-unlock <lock-id>
```

#### 🔧 GitHub Actions Fails
- Check repository secrets are set correctly
- Verify submodule permissions
- Review action logs for specific errors

### Getting Help

1. **📚 Documentation**: `docs/COMPLETE_DEPLOYMENT_GUIDE.md`
2. **🔧 Git Submodules**: `docs/GIT_SUBMODULES_STRATEGY.md`
3. **🐛 Logs**: Check CloudWatch/Cloud Logging/Azure Logs
4. **💬 Community**: HashiCorp forums for Nomad/Terraform

## Advanced Features

### 🔄 Multi-Environment Workflow
```bash
# Development: Auto-deploy on push to main
git push origin main

# Staging: Auto-deploy on PR merge (with approval)  
gh pr create --title "Deploy to staging"

# Production: Manual trigger (with approval)
# Use GitHub Actions web interface
```

### 🌐 Custom Domains
```bash
# AWS Route53
aws route53 create-hosted-zone --name yourdomain.com

# Google Cloud DNS  
gcloud dns managed-zones create yourdomain --dns-name yourdomain.com

# Azure DNS
az network dns zone create --resource-group rg --name yourdomain.com
```

### 📊 Monitoring Setup
- **Grafana Dashboards**: Pre-configured for GenEngine
- **Prometheus Metrics**: Application and infrastructure
- **Alerting**: Critical error notifications
- **Log Aggregation**: Centralized logging

## Next Steps After Deployment

1. **🔗 Set up custom domains** with your DNS provider
2. **📈 Configure monitoring alerts** for production
3. **🔄 Set up backup strategies** for persistent data
4. **🚀 Deploy your first GenEngine** to the cluster
5. **📊 Review performance metrics** and optimize

---

### 🎯 Ready to Deploy?

```bash
# One command to rule them all
./scripts/setup-cloud-credentials.sh

# Then follow the prompts! 🚀
```

**Happy deploying!** 🎉