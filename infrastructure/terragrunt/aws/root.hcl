# Root Terragrunt Configuration
# This file contains common configuration that is inherited by all environments

# Configure Terragrunt to automatically store tfstate files in S3
remote_state {
  backend = "s3"
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  
  config = {
    bucket         = "gengine-terraform-state-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "gengine-terraform-locks-${local.environment}"
    
    # S3 bucket versioning is already enabled via aws-prerequisites.sh
  }
}

# Extract the environment name from the directory structure and define common variables
locals {
  # Get the environment name from the directory path
  # Expected structure: .../aws/ENVIRONMENT/...
  environment = basename(dirname(abspath(path_relative_to_include())))
  
  # Common variables for all environments
  aws_region = "us-west-2"
  project    = "gengine"
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "gengine"
      ManagedBy   = "terragrunt"
      Owner       = "devin"
    }
  }
}

provider "random" {}
provider "tls" {}
EOF
}