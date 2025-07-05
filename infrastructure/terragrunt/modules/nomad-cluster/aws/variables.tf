variable "cluster_name" {
  description = "Name of the Nomad cluster"
  type        = string
}

variable "server_count" {
  description = "Number of Nomad server nodes"
  type        = number
  default     = 3
}

variable "client_count" {
  description = "Number of Nomad client nodes"
  type        = number
  default     = 5
}

variable "server_instance_type" {
  description = "Instance type for Nomad servers"
  type        = string
  default     = "t3.medium"
}

variable "client_instance_type" {
  description = "Instance type for Nomad clients"
  type        = string
  default     = "t3.large"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = []
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for instance access"
  type        = string
  default     = ""
}

variable "enable_bastion" {
  description = "Enable bastion host for SSH access to private instances"
  type        = bool
  default     = false
}

variable "consul_enabled" {
  description = "Enable Consul service discovery"
  type        = bool
  default     = true
}

variable "consul_datacenter" {
  description = "Consul datacenter name"
  type        = string
  default     = "dc1"
}

variable "consul_encrypt_enable" {
  description = "Enable Consul encryption"
  type        = bool
  default     = true
}

variable "vault_enabled" {
  description = "Enable Vault integration"
  type        = bool
  default     = true
}

variable "vault_address" {
  description = "Vault server address"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "prometheus_enabled" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "grafana_enabled" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = true
}

variable "enable_log_forwarding" {
  description = "Enable log forwarding"
  type        = bool
  default     = true
}

variable "log_destination" {
  description = "Log destination (cloudwatch, elasticsearch, etc.)"
  type        = string
  default     = "cloudwatch"
}

variable "enable_autoscaling" {
  description = "Enable auto scaling for client nodes"
  type        = bool
  default     = true
}

variable "min_client_nodes" {
  description = "Minimum number of client nodes"
  type        = number
  default     = 3
}

variable "max_client_nodes" {
  description = "Maximum number of client nodes"
  type        = number
  default     = 20
}

variable "enable_csi_drivers" {
  description = "Enable CSI drivers for persistent storage"
  type        = bool
  default     = true
}

variable "ebs_csi_enabled" {
  description = "Enable EBS CSI driver"
  type        = bool
  default     = true
}

variable "efs_csi_enabled" {
  description = "Enable EFS CSI driver"
  type        = bool
  default     = true
}

variable "enable_alb" {
  description = "Enable Application Load Balancer"
  type        = bool
  default     = true
}

variable "enable_internal_alb" {
  description = "Create internal ALB instead of internet-facing"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the cluster"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "0 2 * * *"
}

variable "retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "enable_security_scanning" {
  description = "Enable security scanning"
  type        = bool
  default     = true
}

variable "vulnerability_scanning" {
  description = "Enable vulnerability scanning"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable WAF for the load balancer"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail logging"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}