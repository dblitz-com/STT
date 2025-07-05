#!/bin/bash
# Multi-Cloud Credentials Setup Script
# Choose and configure credentials for AWS, Google Cloud, or Azure

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"; }
title() { echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"; }

# Display banner
show_banner() {
    title
    echo -e "${CYAN}║                   GenEngine Cloud Setup                         ║${NC}"
    echo -e "${CYAN}║              Multi-Cloud Credential Generation                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in the right directory (Python project)
    if [ ! -d "src/gengines" ] || ( [ ! -f "__init__.py" ] && [ ! -f "__main__.py" ] && [ ! -f "pyproject.toml" ] && [ ! -f "requirements.txt" ] ); then
        error "This script must be run from the GenEngine project root directory"
        exit 1
    fi
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        echo "Install with:"
        echo "  brew install ${missing_tools[*]}  # macOS"
        echo "  apt-get install ${missing_tools[*]}  # Linux"
        exit 1
    fi
    
    # Create .gitignore entry for credentials
    if ! grep -q "credentials/" .gitignore 2>/dev/null; then
        echo "credentials/" >> .gitignore
        log "Added credentials/ to .gitignore"
    fi
    
    log "Prerequisites check completed"
}

# Display cloud provider options
show_cloud_options() {
    echo -e "${CYAN}Available Cloud Providers:${NC}"
    echo
    echo "1. 🔸 AWS (Amazon Web Services)"
    echo "   • EC2, VPC, Route53, S3, DynamoDB"
    echo "   • Mature Terraform provider"
    echo "   • Wide geographical coverage"
    echo
    echo "2. 🔸 Google Cloud Platform (GCP)"
    echo "   • Compute Engine, VPC, Cloud DNS, Cloud Storage"
    echo "   • Excellent container orchestration"
    echo "   • Competitive pricing"
    echo
    echo "3. 🔸 Microsoft Azure"
    echo "   • Virtual Machines, Virtual Networks, DNS, Storage"
    echo "   • Strong enterprise integration"
    echo "   • Hybrid cloud capabilities"
    echo
    echo "4. 🔸 All providers (Multi-cloud setup)"
    echo "   • Configure credentials for all clouds"
    echo "   • Maximum flexibility and redundancy"
    echo
}

# Get cloud provider choice
get_cloud_choice() {
    while true; do
        read -p "Choose a cloud provider (1-4): " choice
        case $choice in
            1)
                export CLOUD_PROVIDER="aws"
                break
                ;;
            2)
                export CLOUD_PROVIDER="gcp"
                break
                ;;
            3)
                export CLOUD_PROVIDER="azure"
                break
                ;;
            4)
                export CLOUD_PROVIDER="all"
                break
                ;;
            *)
                warn "Invalid choice. Please enter 1, 2, 3, or 4."
                ;;
        esac
    done
}

# Setup AWS credentials
setup_aws() {
    log "Setting up AWS credentials..."
    
    if [ ! -f "scripts/generate-aws-credentials.sh" ]; then
        error "AWS credentials script not found"
        exit 1
    fi
    
    chmod +x scripts/generate-aws-credentials.sh
    ./scripts/generate-aws-credentials.sh
}

# Setup GCP credentials
setup_gcp() {
    log "Setting up Google Cloud credentials..."
    
    if [ ! -f "scripts/generate-gcp-credentials.sh" ]; then
        error "GCP credentials script not found"
        exit 1
    fi
    
    chmod +x scripts/generate-gcp-credentials.sh
    ./scripts/generate-gcp-credentials.sh
}

# Setup Azure credentials
setup_azure() {
    log "Setting up Azure credentials..."
    
    if [ ! -f "scripts/generate-azure-credentials.sh" ]; then
        error "Azure credentials script not found"
        exit 1
    fi
    
    chmod +x scripts/generate-azure-credentials.sh
    ./scripts/generate-azure-credentials.sh
}

# Setup all cloud providers
setup_all() {
    log "Setting up credentials for all cloud providers..."
    
    echo
    info "📋 This will configure credentials for AWS, GCP, and Azure"
    info "Make sure you have the following CLIs installed and authenticated:"
    echo "  • aws cli (run 'aws configure' first)"
    echo "  • gcloud cli (run 'gcloud auth login' first)"
    echo "  • az cli (run 'az login' first)"
    echo
    
    read -p "Continue with multi-cloud setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Multi-cloud setup cancelled"
        return
    fi
    
    # Setup each provider
    echo
    log "🔸 Setting up AWS..."
    setup_aws
    
    echo
    log "🔸 Setting up Google Cloud..."
    setup_gcp
    
    echo
    log "🔸 Setting up Azure..."
    setup_azure
    
    echo
    log "✅ Multi-cloud setup completed!"
}

# Validate setup
validate_setup() {
    log "Validating credential setup..."
    
    local validation_passed=true
    
    # Check credential files
    if [ "$CLOUD_PROVIDER" = "aws" ] || [ "$CLOUD_PROVIDER" = "all" ]; then
        if [ ! -f "credentials/aws-credentials.env" ]; then
            error "AWS credentials file not found"
            validation_passed=false
        fi
    fi
    
    if [ "$CLOUD_PROVIDER" = "gcp" ] || [ "$CLOUD_PROVIDER" = "all" ]; then
        if [ ! -f "credentials/gcp-credentials.env" ]; then
            error "GCP credentials file not found"
            validation_passed=false
        fi
    fi
    
    if [ "$CLOUD_PROVIDER" = "azure" ] || [ "$CLOUD_PROVIDER" = "all" ]; then
        if [ ! -f "credentials/azure-credentials.env" ]; then
            error "Azure credentials file not found"
            validation_passed=false
        fi
    fi
    
    # Check .env file
    if [ ! -f ".env" ]; then
        warn ".env file not found (this is normal for first-time setup)"
    fi
    
    if [ "$validation_passed" = true ]; then
        log "✅ Credential validation passed!"
    else
        error "❌ Validation failed. Please check the errors above."
        exit 1
    fi
}

# Show next steps
show_next_steps() {
    log "🎉 Cloud credentials setup completed successfully!"
    echo
    
    info "📁 Files Created:"
    ls -la credentials/ 2>/dev/null || echo "  (credentials directory not found)"
    echo
    
    info "🔧 Next Steps:"
    
    if [ "$CLOUD_PROVIDER" = "aws" ] || [ "$CLOUD_PROVIDER" = "all" ]; then
        echo "📋 AWS:"
        echo "  1. Update domain configuration in .env file"
        echo "  2. Run: ./scripts/aws-prerequisites.sh"
        echo "  3. Deploy: cd infrastructure/terragrunt/aws/development && terragrunt apply"
        echo
    fi
    
    if [ "$CLOUD_PROVIDER" = "gcp" ] || [ "$CLOUD_PROVIDER" = "all" ]; then
        echo "📋 Google Cloud:"
        echo "  1. Create Terraform state bucket: gsutil mb gs://PROJECT-terraform-state-dev"
        echo "  2. Update domain in infrastructure/terragrunt/gcp/env-config/development.hcl"
        echo "  3. Deploy: cd infrastructure/terragrunt/gcp/development && terragrunt apply"
        echo
    fi
    
    if [ "$CLOUD_PROVIDER" = "azure" ] || [ "$CLOUD_PROVIDER" = "all" ]; then
        echo "📋 Azure:"
        echo "  1. Update domain in infrastructure/terragrunt/azure/env-config/development.hcl"
        echo "  2. Deploy: cd infrastructure/terragrunt/azure/development && terragrunt apply"
        echo
    fi
    
    info "🔐 Security Reminders:"
    echo "  • Credential files are excluded from Git (.gitignore)"
    echo "  • GitHub Actions secrets have been configured automatically"
    echo "  • Consider rotating credentials periodically"
    echo "  • Review IAM permissions and apply principle of least privilege"
    echo
    
    info "📚 Documentation:"
    echo "  • Complete deployment guide: docs/COMPLETE_DEPLOYMENT_GUIDE.md"
    echo "  • Git submodules strategy: docs/GIT_SUBMODULES_STRATEGY.md"
    echo "  • Troubleshooting: Check logs and documentation"
}

# Main execution
main() {
    show_banner
    check_prerequisites
    show_cloud_options
    get_cloud_choice
    
    echo
    log "Setting up credentials for: $CLOUD_PROVIDER"
    echo
    
    case $CLOUD_PROVIDER in
        aws)
            setup_aws
            ;;
        gcp)
            setup_gcp
            ;;
        azure)
            setup_azure
            ;;
        all)
            setup_all
            ;;
        *)
            error "Invalid cloud provider: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
    
    validate_setup
    show_next_steps
}

# Handle script arguments
if [ $# -eq 1 ]; then
    case $1 in
        aws|gcp|azure|all)
            export CLOUD_PROVIDER="$1"
            show_banner
            check_prerequisites
            log "Auto-selected cloud provider: $CLOUD_PROVIDER"
            case $CLOUD_PROVIDER in
                aws) setup_aws ;;
                gcp) setup_gcp ;;
                azure) setup_azure ;;
                all) setup_all ;;
            esac
            validate_setup
            show_next_steps
            ;;
        --help|-h)
            show_banner
            echo "Usage: $0 [aws|gcp|azure|all]"
            echo
            echo "Options:"
            echo "  aws     Setup AWS credentials only"
            echo "  gcp     Setup Google Cloud credentials only"
            echo "  azure   Setup Azure credentials only"
            echo "  all     Setup credentials for all cloud providers"
            echo "  --help  Show this help message"
            echo
            echo "If no option is provided, an interactive menu will be shown."
            exit 0
            ;;
        *)
            error "Invalid argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
else
    # Interactive mode
    main "$@"
fi