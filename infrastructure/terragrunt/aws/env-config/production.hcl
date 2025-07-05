# Production Environment-Specific Configuration

# Remote state configuration for production
remote_state {
  backend = "s3"
  config = {
    bucket         = "gengine-terraform-state-production"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "gengine-terraform-locks-production"
    
    # Versioning and lifecycle
    versioning = true
    
    # Security
    server_side_encryption_configuration = {
      rule = {
        apply_server_side_encryption_by_default = {
          sse_algorithm = "AES256"
        }
      }
    }
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Provider configuration for production
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.20"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  
  # Production-specific provider configuration
  default_tags {
    tags = {
      Environment = "production"
      Project     = "gengine"
      ManagedBy   = "terragrunt"
    }
  }
  
  # Assume role for production (optional)
  # assume_role {
  #   role_arn = "arn:aws:iam::ACCOUNT_ID:role/TerraformExecutionRole"
  # }
}
EOF
}

# Input variables specific to production
inputs = {
  # AWS configuration
  aws_region = "us-west-2"
  
  # Domain configuration (to be provided by user)
  domain_name = "gengine.example.com"  # Placeholder domain - update later
  route53_zone_id = ""  # No Route53 zone - using placeholder domain
  
  # Key pair (to be created/provided by user)
  key_pair_name = "gengine-production-keypair"
  
  # Environment-specific sizing
  server_count = 3
  client_count = 5
  
  # Production-grade instance types
  server_instance_type = "t3.medium"
  client_instance_type = "t3.large"
}