#!/bin/bash
# Google Cloud Credentials Generation Script
# Automatically creates service account, roles, and keys for GenEngine deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="gengine"
SERVICE_ACCOUNT_NAME="${PROJECT_NAME}-deployment-sa"
SERVICE_ACCOUNT_DISPLAY_NAME="GenEngine Deployment Service Account"
GCP_REGION=${GCP_REGION:-"us-west1"}
GCP_ZONE=${GCP_ZONE:-"us-west1-a"}

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"; }

# Check if gcloud CLI is installed and configured
check_gcloud_cli() {
    log "Checking Google Cloud CLI configuration..."
    
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud CLI is not installed. Please install it first:"
        echo "  curl https://sdk.cloud.google.com | bash  # Linux/macOS"
        echo "  brew install google-cloud-sdk             # macOS with Homebrew"
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
        error "Google Cloud CLI is not authenticated. Please run 'gcloud auth login' first."
        exit 1
    fi
    
    local current_project=$(gcloud config get-value project 2>/dev/null || echo "")
    local current_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
    
    info "Current Account: $current_account"
    if [ -n "$current_project" ]; then
        info "Current Project: $current_project"
    else
        warn "No project set. You may need to set one with 'gcloud config set project PROJECT_ID'"
    fi
}

# Select or create project
setup_project() {
    log "Setting up Google Cloud project..."
    
    local current_project=$(gcloud config get-value project 2>/dev/null || echo "")
    
    if [ -z "$current_project" ]; then
        echo "Available projects:"
        gcloud projects list --format="table(projectId,name,projectNumber)"
        echo
        read -p "Enter project ID to use (or 'new' to create): " project_choice
        
        if [ "$project_choice" = "new" ]; then
            read -p "Enter new project ID: " new_project_id
            read -p "Enter project name: " new_project_name
            
            gcloud projects create "$new_project_id" --name="$new_project_name"
            gcloud config set project "$new_project_id"
            
            log "Created and set project: $new_project_id"
        else
            gcloud config set project "$project_choice"
            log "Set project: $project_choice"
        fi
    fi
    
    export GCP_PROJECT_ID=$(gcloud config get-value project)
    info "Using project: $GCP_PROJECT_ID"
}

# Enable required APIs
enable_apis() {
    log "Enabling required Google Cloud APIs..."
    
    local apis=(
        "compute.googleapis.com"
        "container.googleapis.com"
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "storage-api.googleapis.com"
        "monitoring.googleapis.com"
        "logging.googleapis.com"
        "dns.googleapis.com"
        "secretmanager.googleapis.com"
        "cloudbuild.googleapis.com"
        "artifactregistry.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            info "API $api already enabled"
        else
            log "Enabling API: $api"
            gcloud services enable "$api"
        fi
    done
    
    log "All required APIs enabled"
}

# Create service account
create_service_account() {
    log "Creating service account for GenEngine deployment..."
    
    # Check if service account exists
    if gcloud iam service-accounts describe "${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" 2>/dev/null; then
        info "Service account $SERVICE_ACCOUNT_NAME already exists"
    else
        gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
            --display-name="$SERVICE_ACCOUNT_DISPLAY_NAME" \
            --description="Service account for GenEngine deployment automation"
        
        log "Service account $SERVICE_ACCOUNT_NAME created successfully"
    fi
    
    export SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
}

# Grant IAM roles
grant_iam_roles() {
    log "Granting IAM roles to service account..."
    
    local roles=(
        "roles/compute.admin"
        "roles/container.admin"
        "roles/iam.serviceAccountAdmin"
        "roles/iam.serviceAccountKeyAdmin"
        "roles/storage.admin"
        "roles/monitoring.admin"
        "roles/logging.admin"
        "roles/dns.admin"
        "roles/secretmanager.admin"
        "roles/cloudbuild.builds.editor"
        "roles/artifactregistry.admin"
        "roles/resourcemanager.projectIamAdmin"
    )
    
    for role in "${roles[@]}"; do
        gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
            --role="$role" \
            --quiet
        
        info "Granted role: $role"
    done
    
    log "All IAM roles granted successfully"
}

# Generate service account key
generate_service_account_key() {
    log "Generating service account key..."
    
    # Create credentials directory
    mkdir -p credentials
    
    local key_file="credentials/gcp-service-account.json"
    
    # Remove existing key file if it exists
    if [ -f "$key_file" ]; then
        warn "Existing service account key found. Creating new one..."
        rm "$key_file"
    fi
    
    # Create new key
    gcloud iam service-accounts keys create "$key_file" \
        --iam-account="$SERVICE_ACCOUNT_EMAIL"
    
    chmod 600 "$key_file"
    
    log "Service account key saved to $key_file"
    
    # Create environment file
    local creds_file="credentials/gcp-credentials.env"
    cat > "$creds_file" << EOF
# Google Cloud Credentials for GenEngine Deployment
# Generated on: $(date)
# Service Account: $SERVICE_ACCOUNT_EMAIL

GOOGLE_APPLICATION_CREDENTIALS=credentials/gcp-service-account.json
GCP_PROJECT_ID=$GCP_PROJECT_ID
GCP_REGION=$GCP_REGION
GCP_ZONE=$GCP_ZONE
GCP_SERVICE_ACCOUNT_EMAIL=$SERVICE_ACCOUNT_EMAIL
EOF
    
    chmod 600 "$creds_file"
    
    log "GCP credentials configuration saved to $creds_file"
}

# Test credentials
test_credentials() {
    log "Testing generated credentials..."
    
    # Set environment variable
    export GOOGLE_APPLICATION_CREDENTIALS="credentials/gcp-service-account.json"
    
    # Test authentication
    if gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null; then
        log "✅ Service account authentication successful!"
        
        # Test API access
        if gcloud projects describe "$GCP_PROJECT_ID" &>/dev/null; then
            log "✅ API access test successful!"
        else
            error "❌ API access test failed"
            exit 1
        fi
    else
        error "❌ Service account authentication failed"
        exit 1
    fi
}

# Set up GitHub Actions secrets
setup_github_secrets() {
    log "Setting up GitHub Actions secrets..."
    
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI not found. Skipping GitHub secrets setup."
        warn "Install with: brew install gh"
        return
    fi
    
    if ! gh auth status &> /dev/null; then
        warn "GitHub CLI not authenticated. Run 'gh auth login' first."
        return
    fi
    
    # Set secrets
    gh secret set GCP_PROJECT_ID -b"$GCP_PROJECT_ID"
    gh secret set GCP_REGION -b"$GCP_REGION"
    gh secret set GCP_ZONE -b"$GCP_ZONE"
    gh secret set GCP_SERVICE_ACCOUNT_EMAIL -b"$SERVICE_ACCOUNT_EMAIL"
    gh secret set GCP_SERVICE_ACCOUNT_KEY < credentials/gcp-service-account.json
    
    log "GitHub Actions secrets configured successfully"
}

# Update .env file
update_env_file() {
    log "Updating .env file with GCP configuration..."
    
    if [ ! -f .env ]; then
        if [ -f .env.template ]; then
            cp .env.template .env
            log "Created .env from template"
        else
            warn ".env.template not found, creating basic .env"
            touch .env
        fi
    fi
    
    # Add GCP configuration to .env
    cat >> .env << EOF

# Google Cloud Configuration (Generated)
GOOGLE_APPLICATION_CREDENTIALS=credentials/gcp-service-account.json
GCP_PROJECT_ID=$GCP_PROJECT_ID
GCP_REGION=$GCP_REGION
GCP_ZONE=$GCP_ZONE
GCP_SERVICE_ACCOUNT_EMAIL=$SERVICE_ACCOUNT_EMAIL
EOF
    
    log ".env file updated with GCP configuration"
}

# Create Terragrunt GCP configuration
create_terragrunt_config() {
    log "Creating Terragrunt configuration for GCP..."
    
    # Create GCP infrastructure directory
    mkdir -p infrastructure/terragrunt/gcp/env-config
    
    # Create base GCP configuration
    cat > infrastructure/terragrunt/gcp/terragrunt.hcl << 'EOF'
# Base Terragrunt configuration for GCP
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env-config/${get_env("ENVIRONMENT", "development")}.hcl"))
}

# Remote state configuration
remote_state {
  backend = "gcs"
  config = {
    bucket   = local.env_vars.inputs.terraform_state_bucket
    prefix   = "${path_relative_to_include()}/terraform.tfstate"
    project  = local.env_vars.inputs.gcp_project_id
    location = local.env_vars.inputs.gcp_region
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}
EOF
}

# Common inputs
inputs = merge(
  local.env_vars.inputs,
  {
    # Add any global inputs here
  }
)
EOF
    
    # Create development environment config
    cat > infrastructure/terragrunt/gcp/env-config/development.hcl << EOF
# Development Environment Configuration for GCP

inputs = {
  # Project configuration
  gcp_project_id = "$GCP_PROJECT_ID"
  gcp_region     = "$GCP_REGION"
  gcp_zone       = "$GCP_ZONE"
  
  # Terraform state bucket
  terraform_state_bucket = "${GCP_PROJECT_ID}-terraform-state-dev"
  
  # Environment-specific configuration
  environment = "development"
  
  # Instance configuration (small for dev)
  instance_type = "e2-small"
  node_count    = 2
  
  # Networking
  vpc_cidr = "10.0.0.0/16"
  
  # Domain configuration (update with your domain)
  domain_name = "dev.gengine.yourcompany.com"
  
  # Common tags
  labels = {
    environment = "development"
    project     = "gengine"
    managed_by  = "terragrunt"
  }
}
EOF
    
    log "Terragrunt GCP configuration created"
}

# Display summary
show_summary() {
    log "Google Cloud credentials generation completed successfully!"
    echo
    info "Created Resources:"
    echo "  • Project: $GCP_PROJECT_ID"
    echo "  • Service Account: $SERVICE_ACCOUNT_EMAIL"
    echo "  • Service Account Key: credentials/gcp-service-account.json"
    echo "  • Enabled APIs: compute, container, iam, storage, etc."
    echo
    info "Files Created:"
    echo "  • credentials/gcp-credentials.env"
    echo "  • infrastructure/terragrunt/gcp/ (Terragrunt config)"
    echo "  • Updated .env file"
    echo
    info "GitHub Actions Secrets Set:"
    echo "  • GCP_PROJECT_ID, GCP_REGION, GCP_ZONE"
    echo "  • GCP_SERVICE_ACCOUNT_EMAIL, GCP_SERVICE_ACCOUNT_KEY"
    echo
    info "Next Steps:"
    echo "1. Create GCS bucket for Terraform state:"
    echo "   gsutil mb gs://${GCP_PROJECT_ID}-terraform-state-dev"
    echo
    echo "2. Update domain in infrastructure/terragrunt/gcp/env-config/development.hcl"
    echo
    echo "3. Deploy infrastructure:"
    echo "   cd infrastructure/terragrunt/gcp/development"
    echo "   terragrunt apply"
    echo
    warn "Security Notes:"
    echo "  • Keep credentials/gcp-service-account.json secure"
    echo "  • Add credentials/ to .gitignore"
    echo "  • Consider key rotation policies"
}

# Main execution
main() {
    log "Starting Google Cloud credentials generation for GenEngine..."
    
    check_gcloud_cli
    setup_project
    enable_apis
    create_service_account
    grant_iam_roles
    generate_service_account_key
    test_credentials
    setup_github_secrets
    update_env_file
    create_terragrunt_config
    show_summary
}

# Execute main function
main "$@"