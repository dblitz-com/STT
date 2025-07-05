# Staging Environment Configuration
# Terragrunt configuration for AWS staging deployment

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment-specific configuration
include "env" {
  path = "${get_terragrunt_dir()}/../env-config/staging.hcl"
}

# Terraform configuration
terraform {
  source = "../../modules/nomad-cluster/aws"
}

# Environment-specific inputs
inputs = {
  # Cluster configuration
  cluster_name = "gengine-nomad-staging"
  environment  = "staging"
  
  # Smaller instances for staging
  server_count        = 3
  client_count        = 3
  server_instance_type = "t3.small"
  client_instance_type = "t3.medium"
  
  # Multi-AZ for testing
  availability_zones = ["us-west-2a", "us-west-2b"]
  
  # Limited auto-scaling for staging
  enable_autoscaling = true
  min_client_nodes   = 2
  max_client_nodes   = 6
  
  # Networking
  vpc_cidr = "10.1.0.0/16"
  
  # Security settings (more permissive for testing)
  allowed_cidr_blocks = ["0.0.0.0/0"]
  enable_waf = false
  enable_cloudtrail = false
  enable_config = false
  enable_vpc_flow_logs = false
  
  # Services enabled
  consul_enabled = true
  vault_enabled = false  # Simpler setup for staging
  enable_monitoring = true
  prometheus_enabled = true
  grafana_enabled = false
  
  # Storage
  enable_csi_drivers = true
  ebs_csi_enabled = true
  efs_csi_enabled = false
  
  # Backup configuration (shorter retention)
  enable_backups = true
  backup_schedule = "0 3 * * *"  # Daily at 3 AM
  retention_period = 7
  
  # Load balancer
  enable_alb = true
  enable_internal_alb = false
  
  # Common tags
  common_tags = {
    Environment = "staging"
    Project     = "gengine"
    Owner       = "devin"
    ManagedBy   = "terragrunt"
    CostCenter  = "engineering"
  }
}