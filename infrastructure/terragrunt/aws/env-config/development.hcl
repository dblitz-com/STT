# Development Environment-Specific Configuration

# Remote state configuration for development
remote_state {
  backend = "s3"
  config = {
    bucket         = "gengine-terraform-state-dev"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "gengine-terraform-locks-dev"
    
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

# Provider configuration for development
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
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  
  # Development-specific provider configuration
  default_tags {
    tags = {
      Environment = "development"
      Project     = "gengine"
      ManagedBy   = "terragrunt"
      AutoShutdown = "true"  # Cost-saving tag for automation
    }
  }
}
EOF
}

# Input variables specific to development
inputs = {
  # AWS configuration
  aws_region = "us-west-2"
  
  # Domain configuration (development subdomain)
  domain_name = "dev.gengine.example.com"  # Placeholder domain - update later
  route53_zone_id = ""  # No Route53 zone - using placeholder domain
  
  # Key pair
  key_pair_name = "gengine-dev-keypair"
  
  # Environment-specific sizing (minimal for cost savings)
  server_count = 3
  client_count = 2
  
  # Development instance types (smallest viable)
  server_instance_type = "t3.micro"
  client_instance_type = "t3.small"
}