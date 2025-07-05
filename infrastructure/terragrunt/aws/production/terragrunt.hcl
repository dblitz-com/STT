# Production Environment Configuration
# Terragrunt configuration for AWS production deployment

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment-specific configuration
include "env" {
  path = "${get_terragrunt_dir()}/../env-config/production.hcl"
}

# Terraform configuration
terraform {
  source = "../../modules/nomad-cluster/aws"
}

# Environment-specific inputs
inputs = {
  # Cluster configuration
  cluster_name = "gengine-nomad-production"
  environment  = "production"
  
  # Instance sizing for production workloads
  server_count        = 3
  client_count        = 5
  server_instance_type = "t3.medium"
  client_instance_type = "t3.large"
  
  # High availability configuration
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  
  # Auto-scaling for production
  enable_autoscaling = true
  min_client_nodes   = 3
  max_client_nodes   = 20
  
  # Networking
  vpc_cidr = "10.0.0.0/16"
  
  # Security settings
  allowed_cidr_blocks = ["0.0.0.0/0"]  # Configure restrictively in actual deployment
  enable_waf = true
  enable_cloudtrail = true
  enable_config = true
  enable_vpc_flow_logs = true
  
  # Services enabled
  consul_enabled = true
  vault_enabled = true
  enable_monitoring = true
  prometheus_enabled = true
  grafana_enabled = true
  
  # Storage
  enable_csi_drivers = true
  ebs_csi_enabled = true
  efs_csi_enabled = true
  
  # Backup configuration
  enable_backups = true
  backup_schedule = "0 2 * * *"  # Daily at 2 AM
  retention_period = 30
  
  # Load balancer
  enable_alb = true
  enable_internal_alb = false
  
  # Common tags
  common_tags = {
    Environment = "production"
    Project     = "gengine"
    Owner       = "devin"
    ManagedBy   = "terragrunt"
    CostCenter  = "engineering"
  }
}