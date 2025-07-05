#!/bin/bash
# AWS Prerequisites Setup Script
# Creates necessary AWS resources for GenEngine Nomad cluster deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-"us-west-2"}
PROJECT_NAME="gengine"
ENVIRONMENTS=("development" "staging" "production")

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

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
        error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local current_region=$(aws configure get region)
    
    info "AWS Account ID: $account_id"
    info "Current Region: $current_region"
    
    if [ "$current_region" != "$AWS_REGION" ]; then
        warn "Current AWS region ($current_region) differs from target region ($AWS_REGION)"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Create S3 buckets for Terraform state
create_s3_buckets() {
    log "Creating S3 buckets for Terraform state..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        local bucket_name="${PROJECT_NAME}-terraform-state-${env}"
        
        if aws s3 ls "s3://$bucket_name" 2>/dev/null; then
            info "S3 bucket $bucket_name already exists"
        else
            log "Creating S3 bucket: $bucket_name"
            
            if [ "$AWS_REGION" = "us-east-1" ]; then
                aws s3 mb "s3://$bucket_name"
            else
                aws s3 mb "s3://$bucket_name" --region "$AWS_REGION"
            fi
            
            # Enable versioning
            aws s3api put-bucket-versioning \
                --bucket "$bucket_name" \
                --versioning-configuration Status=Enabled
            
            # Enable server-side encryption
            aws s3api put-bucket-encryption \
                --bucket "$bucket_name" \
                --server-side-encryption-configuration '{
                    "Rules": [
                        {
                            "ApplyServerSideEncryptionByDefault": {
                                "SSEAlgorithm": "AES256"
                            }
                        }
                    ]
                }'
            
            # Block public access
            aws s3api put-public-access-block \
                --bucket "$bucket_name" \
                --public-access-block-configuration \
                "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
                
            log "S3 bucket $bucket_name created with encryption and versioning enabled"
        fi
    done
}

# Create DynamoDB tables for Terraform state locking
create_dynamodb_tables() {
    log "Creating DynamoDB tables for Terraform state locking..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        local table_name="${PROJECT_NAME}-terraform-locks-${env}"
        
        if aws dynamodb describe-table --table-name "$table_name" --region "$AWS_REGION" 2>/dev/null; then
            info "DynamoDB table $table_name already exists"
        else
            log "Creating DynamoDB table: $table_name"
            
            aws dynamodb create-table \
                --table-name "$table_name" \
                --attribute-definitions AttributeName=LockID,AttributeType=S \
                --key-schema AttributeName=LockID,KeyType=HASH \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region "$AWS_REGION"
            
            # Wait for table to be active
            log "Waiting for table $table_name to become active..."
            aws dynamodb wait table-exists --table-name "$table_name" --region "$AWS_REGION"
            
            log "DynamoDB table $table_name created successfully"
        fi
    done
}

# Create IAM role for Terraform execution
create_terraform_role() {
    log "Creating IAM role for Terraform execution..."
    
    local role_name="${PROJECT_NAME}-terraform-execution-role"
    local policy_name="${PROJECT_NAME}-terraform-execution-policy"
    
    # Check if role exists
    if aws iam get-role --role-name "$role_name" 2>/dev/null; then
        info "IAM role $role_name already exists"
        return
    fi
    
    # Trust policy for Terraform execution
    local trust_policy='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::'$(aws sts get-caller-identity --query Account --output text)':root"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'
    
    # Create role
    aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "$trust_policy" \
        --description "Role for Terraform to manage GenEngine infrastructure"
    
    # Attach managed policies
    local managed_policies=(
        "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
        "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
        "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
        "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
        "arn:aws:iam::aws:policy/AmazonS3FullAccess"
        "arn:aws:iam::aws:policy/CloudWatchFullAccess"
        "arn:aws:iam::aws:policy/IAMFullAccess"
    )
    
    for policy in "${managed_policies[@]}"; do
        aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy"
    done
    
    log "IAM role $role_name created with necessary permissions"
}

# Create key pairs for environments
create_key_pairs() {
    log "Creating EC2 key pairs for environments..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        local key_name="${PROJECT_NAME}-${env}-keypair"
        local key_file="keys/${key_name}.pem"
        
        # Create keys directory if it doesn't exist
        mkdir -p keys
        
        if aws ec2 describe-key-pairs --key-names "$key_name" --region "$AWS_REGION" 2>/dev/null; then
            info "Key pair $key_name already exists"
        else
            log "Creating key pair: $key_name"
            
            aws ec2 create-key-pair \
                --key-name "$key_name" \
                --query 'KeyMaterial' \
                --output text \
                --region "$AWS_REGION" > "$key_file"
            
            chmod 600 "$key_file"
            
            log "Key pair $key_name created and saved to $key_file"
        fi
    done
}

# Validate prerequisites
validate_prerequisites() {
    log "Validating created resources..."
    
    local validation_passed=true
    
    # Check S3 buckets
    for env in "${ENVIRONMENTS[@]}"; do
        local bucket_name="${PROJECT_NAME}-terraform-state-${env}"
        if ! aws s3 ls "s3://$bucket_name" &>/dev/null; then
            error "S3 bucket $bucket_name not found"
            validation_passed=false
        fi
    done
    
    # Check DynamoDB tables
    for env in "${ENVIRONMENTS[@]}"; do
        local table_name="${PROJECT_NAME}-terraform-locks-${env}"
        if ! aws dynamodb describe-table --table-name "$table_name" --region "$AWS_REGION" &>/dev/null; then
            error "DynamoDB table $table_name not found"
            validation_passed=false
        fi
    done
    
    # Check key pairs
    for env in "${ENVIRONMENTS[@]}"; do
        local key_name="${PROJECT_NAME}-${env}-keypair"
        if ! aws ec2 describe-key-pairs --key-names "$key_name" --region "$AWS_REGION" &>/dev/null; then
            error "Key pair $key_name not found"
            validation_passed=false
        fi
    done
    
    if [ "$validation_passed" = true ]; then
        log "All prerequisites validated successfully!"
    else
        error "Validation failed. Please check the errors above."
        exit 1
    fi
}

# Display next steps
show_next_steps() {
    log "AWS prerequisites setup completed successfully!"
    echo
    info "Next steps:"
    echo "1. Update your environment configuration files with actual domain names:"
    echo "   - infrastructure/terragrunt/aws/env-config/production.hcl"
    echo "   - infrastructure/terragrunt/aws/env-config/staging.hcl" 
    echo "   - infrastructure/terragrunt/aws/env-config/development.hcl"
    echo
    echo "2. If using a custom domain, create/configure Route53 hosted zone:"
    echo "   aws route53 create-hosted-zone --name your-domain.com --caller-reference \$(date +%s)"
    echo
    echo "3. Deploy infrastructure:"
    echo "   cd infrastructure/terragrunt/aws/development"
    echo "   terragrunt plan"
    echo "   terragrunt apply"
    echo
    echo "4. Configure GitHub Actions secrets:"
    echo "   - AWS_ACCESS_KEY_ID"
    echo "   - AWS_SECRET_ACCESS_KEY"
    echo "   - AWS_REGION"
    echo
    info "Key files created in ./keys/ directory (keep these secure!)"
}

# Main execution
main() {
    log "Starting AWS prerequisites setup for GenEngine..."
    
    check_aws_cli
    create_s3_buckets
    create_dynamodb_tables
    create_terraform_role
    create_key_pairs
    validate_prerequisites
    show_next_steps
}

# Execute main function
main "$@"