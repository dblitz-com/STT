# Agent Sandbox Module Outputs
# Exposes sandbox infrastructure and configuration for integration

output "security_group_id" {
  description = "Security group ID for agent sandboxes"
  value       = aws_security_group.agent_sandbox.id
}

output "security_group_arn" {
  description = "Security group ARN for agent sandboxes"
  value       = aws_security_group.agent_sandbox.arn
}

output "persistent_volume_ids" {
  description = "Map of persistent EBS volume IDs by volume name"
  value       = { for k, v in aws_ebs_volume.agent_persistent_storage : k => v.id }
}

output "persistent_volume_arns" {
  description = "Map of persistent EBS volume ARNs by volume name"
  value       = { for k, v in aws_ebs_volume.agent_persistent_storage : k => v.arn }
}

output "shared_storage_id" {
  description = "EFS file system ID for shared storage (if enabled)"
  value       = var.storage_config.shared_storage.enabled ? aws_efs_file_system.agent_shared_storage[0].id : null
}

output "shared_storage_arn" {
  description = "EFS file system ARN for shared storage (if enabled)"
  value       = var.storage_config.shared_storage.enabled ? aws_efs_file_system.agent_shared_storage[0].arn : null
}

output "shared_storage_dns_name" {
  description = "EFS file system DNS name for mounting (if enabled)"
  value       = var.storage_config.shared_storage.enabled ? aws_efs_file_system.agent_shared_storage[0].dns_name : null
}

output "execution_role_arn" {
  description = "IAM role ARN for sandbox execution"
  value       = aws_iam_role.sandbox_execution_role.arn
}

output "execution_role_name" {
  description = "IAM role name for sandbox execution"
  value       = aws_iam_role.sandbox_execution_role.name
}

output "log_group_name" {
  description = "CloudWatch log group name for sandbox monitoring"
  value       = aws_cloudwatch_log_group.agent_sandbox_logs.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for sandbox monitoring"
  value       = aws_cloudwatch_log_group.agent_sandbox_logs.arn
}

output "security_violations_alarm_arn" {
  description = "CloudWatch alarm ARN for security violations"
  value       = aws_cloudwatch_metric_alarm.security_violations_alarm.arn
}

output "sandbox_job_template_path" {
  description = "Path to the sandbox Nomad job template file"
  value       = local_file.sandbox_job_template.filename
}

output "sandbox_configuration" {
  description = "Complete sandbox configuration summary"
  value = {
    cluster_name     = var.cluster_name
    environment      = var.environment
    base_image       = var.sandbox_config.base_image
    enable_internet  = var.sandbox_config.enable_internet
    max_execution_time = var.sandbox_config.max_execution_time
    
    security_policies = {
      enable_seccomp       = var.security_policies.enable_seccomp
      enable_apparmor      = var.security_policies.enable_apparmor
      max_processes        = var.security_policies.max_processes
      max_open_files       = var.security_policies.max_open_files
      allowed_syscalls_count = length(var.security_policies.allowed_syscalls)
      blocked_syscalls_count = length(var.security_policies.blocked_syscalls)
    }
    
    resource_quotas = var.resource_quotas
    
    storage = {
      persistent_volumes_count = length(var.storage_config.persistent_volumes)
      shared_storage_enabled   = var.storage_config.shared_storage.enabled
      ephemeral_storage_size   = var.sandbox_config.temp_storage_size
    }
    
    monitoring = {
      enable_metrics    = var.monitoring_config.enable_metrics
      retention_days    = var.monitoring_config.retention_days
      log_level        = var.monitoring_config.log_level
    }
  }
  sensitive = false
}

output "agent_type_configurations" {
  description = "Resource quotas and limits per agent type"
  value = {
    for agent_type, quota in var.resource_quotas : agent_type => {
      cpu_limit    = quota.cpu_limit
      memory_limit = quota.memory_limit
      disk_limit   = quota.disk_limit
      gpu_limit    = quota.gpu_limit
      max_runtime  = quota.max_runtime
    }
  }
}

output "network_configuration" {
  description = "Network configuration for sandbox integration"
  value = {
    vpc_id               = var.network_config.vpc_id
    subnet_ids           = var.network_config.subnet_ids
    security_group_id    = aws_security_group.agent_sandbox.id
    allowed_ports        = var.network_config.allowed_ports
    enable_nat_gateway   = var.network_config.enable_nat_gateway
    dns_servers          = var.network_config.dns_servers
  }
  sensitive = false
}

output "integration_endpoints" {
  description = "Integration configuration for external services"
  value = {
    github_app_id          = var.integration_config.github_app_id
    github_installation_id = var.integration_config.github_installation_id
    webhook_url            = var.integration_config.webhook_url
    vault_integration      = var.integration_config.vault_integration
    consul_integration     = var.integration_config.consul_integration
  }
  sensitive = false
}

output "cleanup_configuration" {
  description = "Cleanup and lifecycle management settings"
  value = {
    auto_cleanup_enabled = var.cleanup_config.auto_cleanup_enabled
    cleanup_interval     = var.cleanup_config.cleanup_interval
    max_idle_time        = var.cleanup_config.max_idle_time
    max_lifetime         = var.cleanup_config.max_lifetime
    cleanup_on_failure   = var.cleanup_config.cleanup_on_failure
  }
}

output "monitoring_resources" {
  description = "Monitoring and observability resource identifiers"
  value = {
    log_group_name           = aws_cloudwatch_log_group.agent_sandbox_logs.name
    security_metric_name     = aws_cloudwatch_log_metric_filter.security_violations.metric_transformation[0].name
    resource_limit_metric    = aws_cloudwatch_log_metric_filter.resource_limits_exceeded.metric_transformation[0].name
    security_alarm_name      = aws_cloudwatch_metric_alarm.security_violations_alarm.alarm_name
    metrics_namespace        = "AgentSandbox"
  }
}