# Staging Environment-Specific Configuration

# Remote state configuration for staging
remote_state {
  backend = "s3"
  config = {
    bucket         = "gengine-terraform-state-staging"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "gengine-terraform-locks-staging"
    
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

# Provider configuration for staging
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
  
  # Staging-specific provider configuration
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "gengine"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

# Input variables specific to staging
inputs = {
  # AWS configuration
  aws_region = "us-west-2"
  
  # Domain configuration (staging subdomain)
  domain_name = "staging.gengine.example.com"  # Placeholder domain - update later
  route53_zone_id = ""  # No Route53 zone - using placeholder domain
  
  # Key pair
  key_pair_name = "gengine-staging-keypair"
  
  # Environment-specific sizing
  server_count = 3
  client_count = 3
  
  # Staging instance types (smaller)
  server_instance_type = "t3.small"
  client_instance_type = "t3.medium"
}