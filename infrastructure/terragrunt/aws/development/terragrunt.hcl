# Development Environment Configuration
# Terragrunt configuration for AWS development deployment

# Include root configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Terraform configuration
terraform {
  source = "../../modules/nomad-cluster/aws"
}

# Environment-specific inputs
inputs = {
  # Cluster configuration
  cluster_name = "gengine-nomad-dev"
  environment  = "development"
  
  # Domain configuration
  domain_name = "dev.gengine.example.com"
  route53_zone_id = ""
  
  # Minimal instances for development
  server_count        = 3
  client_count        = 2
  server_instance_type = "t3.micro"
  client_instance_type = "t3.small"
  
  # Minimum 2 AZs required for ALB
  availability_zones = ["us-west-2a", "us-west-2b"]
  
  # No auto-scaling for dev
  enable_autoscaling = false
  min_client_nodes   = 2
  max_client_nodes   = 3
  
  # Networking
  vpc_cidr = "10.2.0.0/16"
  
  # Security settings (development-friendly)
  allowed_cidr_blocks = ["0.0.0.0/0"]
  enable_waf = false
  enable_cloudtrail = false
  enable_config = false
  enable_vpc_flow_logs = false
  
  # Services enabled (minimal for dev)
  consul_enabled = true
  vault_enabled = false
  enable_monitoring = true
  prometheus_enabled = false
  grafana_enabled = false
  
  # Storage
  enable_csi_drivers = false
  ebs_csi_enabled = false
  efs_csi_enabled = false
  
  # Backup configuration (minimal)
  enable_backups = false
  backup_schedule = ""
  retention_period = 3
  
  # Load balancer
  enable_alb = true
  enable_internal_alb = false
  
  # Common tags
  common_tags = {
    Environment = "development"
    Project     = "gengine"
    Owner       = "devin"
    ManagedBy   = "terragrunt"
    CostCenter  = "engineering"
    AutoShutdown = "true"  # Can be used for cost-saving automation
  }
}