#!/bin/bash
# Azure Credentials Generation Script
# Automatically creates service principal, resource group, and keys for GenEngine deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="gengine"
SERVICE_PRINCIPAL_NAME="${PROJECT_NAME}-deployment-sp"
RESOURCE_GROUP_NAME="${PROJECT_NAME}-rg"
AZURE_REGION=${AZURE_REGION:-"East US"}
STORAGE_ACCOUNT_NAME="${PROJECT_NAME}tfstate$(date +%s | tail -c 6)"  # Unique name

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"; }

# Check if Azure CLI is installed and configured
check_azure_cli() {
    log "Checking Azure CLI configuration..."
    
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed. Please install it first:"
        echo "  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash  # Linux"
        echo "  brew install azure-cli                                  # macOS"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        error "Azure CLI is not authenticated. Please run 'az login' first."
        exit 1
    fi
    
    local subscription_id=$(az account show --query id --output tsv)
    local subscription_name=$(az account show --query name --output tsv)
    local tenant_id=$(az account show --query tenantId --output tsv)
    
    info "Subscription ID: $subscription_id"
    info "Subscription: $subscription_name"
    info "Tenant ID: $tenant_id"
    
    export AZURE_SUBSCRIPTION_ID="$subscription_id"
    export AZURE_TENANT_ID="$tenant_id"
}

# Create resource group
create_resource_group() {
    log "Creating resource group for GenEngine..."
    
    if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
        info "Resource group $RESOURCE_GROUP_NAME already exists"
    else
        az group create \
            --name "$RESOURCE_GROUP_NAME" \
            --location "$AZURE_REGION" \
            --tags project=gengine purpose=deployment
        
        log "Resource group $RESOURCE_GROUP_NAME created in $AZURE_REGION"
    fi
}

# Create storage account for Terraform state
create_storage_account() {
    log "Creating storage account for Terraform state..."
    
    if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
        info "Storage account $STORAGE_ACCOUNT_NAME already exists"
    else
        az storage account create \
            --name "$STORAGE_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --location "$AZURE_REGION" \
            --sku Standard_LRS \
            --encryption-services blob \
            --tags project=gengine purpose=terraform-state
        
        log "Storage account $STORAGE_ACCOUNT_NAME created"
    fi
    
    # Create container for Terraform state
    local storage_key=$(az storage account keys list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --query '[0].value' --output tsv)
    
    if az storage container show \
        --name "tfstate" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --account-key "$storage_key" &>/dev/null; then
        info "Storage container 'tfstate' already exists"
    else
        az storage container create \
            --name "tfstate" \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --account-key "$storage_key"
        
        log "Storage container 'tfstate' created"
    fi
    
    export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_NAME"
    export AZURE_STORAGE_KEY="$storage_key"
}

# Create service principal
create_service_principal() {
    log "Creating service principal for GenEngine deployment..."
    
    # Check if service principal already exists
    local existing_sp=$(az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query '[0].appId' --output tsv)
    
    if [ -n "$existing_sp" ] && [ "$existing_sp" != "null" ]; then
        warn "Service principal $SERVICE_PRINCIPAL_NAME already exists"
        read -p "Do you want to reset credentials? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Resetting credentials for existing service principal..."
            local sp_output=$(az ad sp credential reset --name "$existing_sp" --output json)
        else
            error "Cannot proceed without resetting credentials. Exiting."
            exit 1
        fi
    else
        log "Creating new service principal..."
        local sp_output=$(az ad sp create-for-rbac \
            --name "$SERVICE_PRINCIPAL_NAME" \
            --role Contributor \
            --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID" \
            --output json)
    fi
    
    # Extract service principal information
    export AZURE_CLIENT_ID=$(echo "$sp_output" | jq -r '.appId')
    export AZURE_CLIENT_SECRET=$(echo "$sp_output" | jq -r '.password')
    
    log "Service principal created/updated successfully"
    info "Client ID: $AZURE_CLIENT_ID"
}

# Grant additional permissions
grant_permissions() {
    log "Granting additional permissions to service principal..."
    
    # Grant additional roles for comprehensive access
    local roles=(
        "Storage Blob Data Contributor"
        "Key Vault Administrator"
        "DNS Zone Contributor"
        "Network Contributor"
        "Virtual Machine Contributor"
        "Monitoring Contributor"
    )
    
    for role in "${roles[@]}"; do
        az role assignment create \
            --assignee "$AZURE_CLIENT_ID" \
            --role "$role" \
            --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID" \
            --output none 2>/dev/null || info "Role '$role' may already be assigned"
        
        info "Granted role: $role"
    done
    
    log "Additional permissions granted successfully"
}

# Generate credentials file
generate_credentials_file() {
    log "Generating Azure credentials file..."
    
    # Create credentials directory
    mkdir -p credentials
    
    local creds_file="credentials/azure-credentials.env"
    cat > "$creds_file" << EOF
# Azure Credentials for GenEngine Deployment
# Generated on: $(date)
# Service Principal: $SERVICE_PRINCIPAL_NAME

AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_REGION=$AZURE_REGION
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP_NAME
AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY
EOF
    
    chmod 600 "$creds_file"
    
    log "Azure credentials saved to $creds_file"
}

# Test credentials
test_credentials() {
    log "Testing generated credentials..."
    
    # Test service principal login
    if az login --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$AZURE_CLIENT_SECRET" \
        --tenant "$AZURE_TENANT_ID" &>/dev/null; then
        
        log "✅ Service principal authentication successful!"
        
        # Test resource access
        if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
            log "✅ Resource access test successful!"
        else
            error "❌ Resource access test failed"
            exit 1
        fi
        
        # Switch back to user account
        az logout &>/dev/null
        az login &>/dev/null
        
    else
        error "❌ Service principal authentication failed"
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
    gh secret set AZURE_CLIENT_ID -b"$AZURE_CLIENT_ID"
    gh secret set AZURE_CLIENT_SECRET -b"$AZURE_CLIENT_SECRET"
    gh secret set AZURE_SUBSCRIPTION_ID -b"$AZURE_SUBSCRIPTION_ID"
    gh secret set AZURE_TENANT_ID -b"$AZURE_TENANT_ID"
    gh secret set AZURE_REGION -b"$AZURE_REGION"
    gh secret set AZURE_RESOURCE_GROUP -b"$RESOURCE_GROUP_NAME"
    gh secret set AZURE_STORAGE_ACCOUNT -b"$AZURE_STORAGE_ACCOUNT"
    
    log "GitHub Actions secrets configured successfully"
}

# Update .env file
update_env_file() {
    log "Updating .env file with Azure configuration..."
    
    if [ ! -f .env ]; then
        if [ -f .env.template ]; then
            cp .env.template .env
            log "Created .env from template"
        else
            warn ".env.template not found, creating basic .env"
            touch .env
        fi
    fi
    
    # Add Azure configuration to .env
    cat >> .env << EOF

# Azure Configuration (Generated)
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_REGION=$AZURE_REGION
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP_NAME
AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
EOF
    
    log ".env file updated with Azure configuration"
}

# Create Terragrunt Azure configuration
create_terragrunt_config() {
    log "Creating Terragrunt configuration for Azure..."
    
    # Create Azure infrastructure directory
    mkdir -p infrastructure/terragrunt/azure/env-config
    
    # Create base Azure configuration
    cat > infrastructure/terragrunt/azure/terragrunt.hcl << 'EOF'
# Base Terragrunt configuration for Azure
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env-config/${get_env("ENVIRONMENT", "development")}.hcl"))
}

# Remote state configuration
remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = local.env_vars.inputs.azure_resource_group
    storage_account_name = local.env_vars.inputs.azure_storage_account
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
}

provider "azuread" {
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id     = var.azure_tenant_id
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
    cat > infrastructure/terragrunt/azure/env-config/development.hcl << EOF
# Development Environment Configuration for Azure

inputs = {
  # Azure configuration
  azure_subscription_id = "$AZURE_SUBSCRIPTION_ID"
  azure_tenant_id       = "$AZURE_TENANT_ID"
  azure_region          = "$AZURE_REGION"
  azure_resource_group  = "$RESOURCE_GROUP_NAME"
  azure_storage_account = "$AZURE_STORAGE_ACCOUNT"
  
  # Environment-specific configuration
  environment = "development"
  
  # Instance configuration (small for dev)
  vm_size    = "Standard_B2s"
  node_count = 2
  
  # Networking
  vnet_cidr = "10.0.0.0/16"
  
  # Domain configuration (update with your domain)
  domain_name = "dev.gengine.yourcompany.com"
  
  # Common tags
  tags = {
    environment = "development"
    project     = "gengine"
    managed_by  = "terragrunt"
  }
}
EOF
    
    log "Terragrunt Azure configuration created"
}

# Display summary
show_summary() {
    log "Azure credentials generation completed successfully!"
    echo
    info "Created Resources:"
    echo "  • Resource Group: $RESOURCE_GROUP_NAME"
    echo "  • Service Principal: $SERVICE_PRINCIPAL_NAME"
    echo "  • Storage Account: $AZURE_STORAGE_ACCOUNT"
    echo "  • Storage Container: tfstate"
    echo
    info "Files Created:"
    echo "  • credentials/azure-credentials.env"
    echo "  • infrastructure/terragrunt/azure/ (Terragrunt config)"
    echo "  • Updated .env file"
    echo
    info "GitHub Actions Secrets Set:"
    echo "  • AZURE_CLIENT_ID, AZURE_CLIENT_SECRET"
    echo "  • AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID"
    echo "  • AZURE_REGION, AZURE_RESOURCE_GROUP"
    echo
    info "Next Steps:"
    echo "1. Update domain in infrastructure/terragrunt/azure/env-config/development.hcl"
    echo
    echo "2. Deploy infrastructure:"
    echo "   cd infrastructure/terragrunt/azure/development"
    echo "   terragrunt apply"
    echo
    echo "3. For production, consider using Azure Key Vault for secrets"
    echo
    warn "Security Notes:"
    echo "  • Keep credentials/azure-credentials.env secure"
    echo "  • Add credentials/ to .gitignore"
    echo "  • Consider using Managed Identity in production"
    echo "  • Rotate service principal credentials regularly"
}

# Main execution
main() {
    log "Starting Azure credentials generation for GenEngine..."
    
    check_azure_cli
    create_resource_group
    create_storage_account
    create_service_principal
    grant_permissions
    generate_credentials_file
    test_credentials
    setup_github_secrets
    update_env_file
    create_terragrunt_config
    show_summary
}

# Execute main function
main "$@"