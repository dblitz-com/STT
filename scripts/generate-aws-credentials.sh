#!/bin/bash
# AWS Credentials Generation Script
# Automatically creates IAM user, policies, and access keys for GenEngine deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="gengine"
IAM_USER_NAME="${PROJECT_NAME}-deployment-user"
IAM_POLICY_NAME="${PROJECT_NAME}-deployment-policy"
IAM_GROUP_NAME="${PROJECT_NAME}-deployment-group"
AWS_REGION=${AWS_REGION:-"us-west-2"}

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"; }

# Check if AWS CLI is installed and configured
check_aws_cli() {
    log "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first:"
        echo "  brew install awscli  # macOS"
        echo "  pip install awscli   # Linux/Windows"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS CLI is not configured. Please run 'aws configure' first with admin credentials."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local current_user=$(aws sts get-caller-identity --query Arn --output text)
    
    info "AWS Account ID: $account_id"
    info "Current User/Role: $current_user"
}

# Create IAM policy with necessary permissions
create_iam_policy() {
    log "Creating IAM policy for GenEngine deployment..."
    
    # Check if policy already exists
    if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$IAM_POLICY_NAME" 2>/dev/null; then
        info "IAM policy $IAM_POLICY_NAME already exists"
        return
    fi
    
    # Create comprehensive policy document
    local policy_document='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:*",
                    "vpc:*",
                    "iam:*",
                    "s3:*",
                    "dynamodb:*",
                    "route53:*",
                    "elasticloadbalancing:*",
                    "cloudwatch:*",
                    "logs:*",
                    "autoscaling:*",
                    "application-autoscaling:*",
                    "ssm:*",
                    "secretsmanager:*",
                    "kms:*",
                    "acm:*",
                    "wafv2:*",
                    "cloudtrail:*",
                    "config:*",
                    "backup:*",
                    "sns:*",
                    "sqs:*"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "sts:AssumeRole",
                    "sts:GetCallerIdentity"
                ],
                "Resource": "*"
            }
        ]
    }'
    
    # Create the policy
    aws iam create-policy \
        --policy-name "$IAM_POLICY_NAME" \
        --policy-document "$policy_document" \
        --description "Policy for GenEngine deployment automation"
    
    log "IAM policy $IAM_POLICY_NAME created successfully"
}

# Create IAM group
create_iam_group() {
    log "Creating IAM group for GenEngine deployment..."
    
    # Check if group already exists
    if aws iam get-group --group-name "$IAM_GROUP_NAME" 2>/dev/null; then
        info "IAM group $IAM_GROUP_NAME already exists"
    else
        aws iam create-group --group-name "$IAM_GROUP_NAME"
        log "IAM group $IAM_GROUP_NAME created successfully"
    fi
    
    # Attach policy to group
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    aws iam attach-group-policy \
        --group-name "$IAM_GROUP_NAME" \
        --policy-arn "arn:aws:iam::$account_id:policy/$IAM_POLICY_NAME"
    
    log "Policy attached to group $IAM_GROUP_NAME"
}

# Create IAM user
create_iam_user() {
    log "Creating IAM user for GenEngine deployment..."
    
    # Check if user already exists
    if aws iam get-user --user-name "$IAM_USER_NAME" 2>/dev/null; then
        warn "IAM user $IAM_USER_NAME already exists"
        
        # Check if user has access keys
        local existing_keys=$(aws iam list-access-keys --user-name "$IAM_USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
        if [ -n "$existing_keys" ]; then
            warn "User already has access keys. Do you want to create new ones? (existing will be deleted)"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Skipping user creation"
                return
            fi
            
            # Delete existing access keys
            for key_id in $existing_keys; do
                aws iam delete-access-key --user-name "$IAM_USER_NAME" --access-key-id "$key_id"
                log "Deleted existing access key: $key_id"
            done
        fi
    else
        # Create the user
        aws iam create-user \
            --user-name "$IAM_USER_NAME" \
            --tags Key=Project,Value=GenEngine Key=Purpose,Value=Deployment
        
        log "IAM user $IAM_USER_NAME created successfully"
    fi
    
    # Add user to group
    aws iam add-user-to-group \
        --group-name "$IAM_GROUP_NAME" \
        --user-name "$IAM_USER_NAME"
    
    log "User $IAM_USER_NAME added to group $IAM_GROUP_NAME"
}

# Generate access keys
generate_access_keys() {
    log "Generating access keys for $IAM_USER_NAME..."
    
    # Create access key
    local key_output=$(aws iam create-access-key --user-name "$IAM_USER_NAME" --output json)
    local access_key_id=$(echo "$key_output" | jq -r '.AccessKey.AccessKeyId')
    local secret_access_key=$(echo "$key_output" | jq -r '.AccessKey.SecretAccessKey')
    
    # Create credentials directory
    mkdir -p credentials
    
    # Save credentials to file
    local creds_file="credentials/aws-credentials.env"
    cat > "$creds_file" << EOF
# AWS Credentials for GenEngine Deployment
# Generated on: $(date)
# IAM User: $IAM_USER_NAME

AWS_ACCESS_KEY_ID=$access_key_id
AWS_SECRET_ACCESS_KEY=$secret_access_key
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EOF
    
    chmod 600 "$creds_file"
    
    log "Access keys generated and saved to $creds_file"
    
    # Test the credentials
    log "Testing generated credentials..."
    AWS_ACCESS_KEY_ID="$access_key_id" AWS_SECRET_ACCESS_KEY="$secret_access_key" \
        aws sts get-caller-identity &> /dev/null
    
    if [ $? -eq 0 ]; then
        log "✅ Credentials tested successfully!"
    else
        error "❌ Credential test failed"
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
    
    # Source the credentials
    source credentials/aws-credentials.env
    
    # Set secrets
    gh secret set AWS_ACCESS_KEY_ID -b"$AWS_ACCESS_KEY_ID"
    gh secret set AWS_SECRET_ACCESS_KEY -b"$AWS_SECRET_ACCESS_KEY"
    gh secret set AWS_REGION -b"$AWS_REGION"
    gh secret set AWS_ACCOUNT_ID -b"$AWS_ACCOUNT_ID"
    
    log "GitHub Actions secrets configured successfully"
}

# Update .env file
update_env_file() {
    log "Updating .env file with generated credentials..."
    
    if [ ! -f .env ]; then
        if [ -f .env.template ]; then
            cp .env.template .env
            log "Created .env from template"
        else
            error ".env.template not found"
            return
        fi
    fi
    
    # Source the credentials
    source credentials/aws-credentials.env
    
    # Update .env file using sed
    sed -i.bak \
        -e "s/AWS_ACCESS_KEY_ID=.*/AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID/" \
        -e "s/AWS_SECRET_ACCESS_KEY=.*/AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY/" \
        -e "s/AWS_REGION=.*/AWS_REGION=$AWS_REGION/" \
        -e "s/AWS_ACCOUNT_ID=.*/AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID/" \
        .env
    
    log ".env file updated with AWS credentials"
}

# Display summary
show_summary() {
    log "AWS credentials generation completed successfully!"
    echo
    info "Created Resources:"
    echo "  • IAM Policy: $IAM_POLICY_NAME"
    echo "  • IAM Group: $IAM_GROUP_NAME" 
    echo "  • IAM User: $IAM_USER_NAME"
    echo "  • Access Keys: credentials/aws-credentials.env"
    echo
    info "Files Updated:"
    echo "  • .env (with AWS credentials)"
    echo "  • GitHub Actions secrets (if gh CLI available)"
    echo
    info "Next Steps:"
    echo "1. Update domain configuration in .env file:"
    echo "   PRODUCTION_DOMAIN=api.yourcompany.com"
    echo "   ROUTE53_ZONE_ID=Z1234567890ABC"
    echo
    echo "2. Run AWS prerequisites setup:"
    echo "   ./scripts/aws-prerequisites.sh"
    echo
    echo "3. Deploy infrastructure:"
    echo "   cd infrastructure/terragrunt/aws/development"
    echo "   terragrunt apply"
    echo
    warn "Security Note:"
    echo "  • Keep credentials/aws-credentials.env secure"
    echo "  • Add credentials/ to .gitignore"
    echo "  • Consider rotating keys periodically"
}

# Main execution
main() {
    log "Starting AWS credentials generation for GenEngine..."
    
    check_aws_cli
    create_iam_policy
    create_iam_group
    create_iam_user
    generate_access_keys
    setup_github_secrets
    update_env_file
    show_summary
}

# Execute main function
main "$@"