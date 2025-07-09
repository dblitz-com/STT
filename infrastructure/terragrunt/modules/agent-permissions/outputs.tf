# Agent Permissions Module Outputs
# Exposes IAM roles, policies, and permission configurations

output "agent_base_role_arn" {
  description = "ARN of the base IAM role for all agents"
  value       = aws_iam_role.agent_base_role.arn
}

output "agent_base_role_name" {
  description = "Name of the base IAM role for all agents"
  value       = aws_iam_role.agent_base_role.name
}

output "agent_type_role_arns" {
  description = "Map of agent type to IAM role ARN"
  value       = { for k, v in aws_iam_role.agent_type_roles : k => v.arn }
}

output "agent_type_role_names" {
  description = "Map of agent type to IAM role name"
  value       = { for k, v in aws_iam_role.agent_type_roles : k => v.name }
}

output "agent_base_policy_arn" {
  description = "ARN of the base policy for all agents"
  value       = aws_iam_policy.agent_base_policy.arn
}

output "agent_type_policy_arns" {
  description = "Map of agent type to policy ARN"
  value       = { for k, v in aws_iam_policy.agent_type_policies : k => v.arn }
}

output "github_integration_policy_arn" {
  description = "ARN of the GitHub integration policy"
  value       = aws_iam_policy.github_integration_policy.arn
}

output "vault_integration_policy_arn" {
  description = "ARN of the Vault integration policy (if enabled)"
  value       = var.vault_config.vault_endpoint != "" ? aws_iam_policy.vault_integration_policy[0].arn : null
}

output "cross_account_role_arns" {
  description = "Map of cross-account role names to ARNs (if enabled)"
  value       = var.cross_account_config.enabled ? { for k, v in aws_iam_role.cross_account_roles : k => v.arn } : {}
}

output "integration_role_arns" {
  description = "Map of integration service names to role ARNs"
  value       = { for k, v in aws_iam_role.integration_roles : k => v.arn }
}

output "integration_role_names" {
  description = "Map of integration service names to role names"
  value       = { for k, v in aws_iam_role.integration_roles : k => v.name }
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail for permission auditing (if enabled)"
  value       = var.monitoring_config.enable_cloudtrail ? aws_cloudtrail.agent_permissions_trail[0].arn : null
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs (if enabled)"
  value       = var.monitoring_config.enable_cloudtrail ? aws_s3_bucket.cloudtrail_bucket[0].bucket : null
}

output "access_log_group_name" {
  description = "Name of the CloudWatch log group for access logs (if enabled)"
  value       = var.monitoring_config.enable_access_logging ? aws_cloudwatch_log_group.agent_access_logs[0].name : null
}

output "access_log_group_arn" {
  description = "ARN of the CloudWatch log group for access logs (if enabled)"
  value       = var.monitoring_config.enable_access_logging ? aws_cloudwatch_log_group.agent_access_logs[0].arn : null
}

output "security_alarm_arns" {
  description = "ARNs of security monitoring alarms (if enabled)"
  value = var.monitoring_config.enable_alerts ? {
    unauthorized_access = var.monitoring_config.alert_sns_topic_arn != "" ? aws_cloudwatch_metric_alarm.unauthorized_access_alarm[0].arn : null
  } : {}
}

output "permission_configuration" {
  description = "Complete permissions configuration summary"
  value = {
    cluster_name  = var.cluster_name
    environment   = var.environment
    
    agent_types = {
      for agent_type, config in var.agent_types : agent_type => {
        role_arn             = aws_iam_role.agent_type_roles[agent_type].arn
        policy_arn           = aws_iam_policy.agent_type_policies[agent_type].arn
        github_permissions   = config.github_permissions
        aws_permissions      = config.aws_permissions
        vault_policies       = config.vault_policies
        resource_access      = config.resource_access
        cross_account_access = config.cross_account_access
      }
    }
    
    security_policies = {
      enforce_mfa              = var.security_policies.enforce_mfa
      require_request_signing  = var.security_policies.require_request_signing
      ip_restriction_enabled   = var.security_policies.ip_restriction_enabled
      session_duration_seconds = var.security_policies.session_duration_seconds
      external_id_required     = var.security_policies.external_id_required
    }
    
    integrations = {
      github_enabled = true
      vault_enabled  = var.vault_config.vault_endpoint != ""
      cross_account_enabled = var.cross_account_config.enabled
    }
    
    monitoring = {
      cloudtrail_enabled     = var.monitoring_config.enable_cloudtrail
      access_logging_enabled = var.monitoring_config.enable_access_logging
      alerts_enabled         = var.monitoring_config.enable_alerts
      log_retention_days     = var.monitoring_config.log_retention_days
    }
  }
  sensitive = false
}

output "github_app_configuration" {
  description = "GitHub App integration configuration"
  value = {
    app_id                   = var.github_app_config.app_id
    installation_id          = var.github_app_config.installation_id
    private_key_secret_arn   = var.github_app_config.private_key_secret_arn
    webhook_secret_arn       = var.github_app_config.webhook_secret_arn
    permissions              = var.github_app_config.permissions
  }
  sensitive = false
}

output "vault_configuration" {
  description = "HashiCorp Vault integration configuration (if enabled)"
  value = var.vault_config.vault_endpoint != "" ? {
    vault_endpoint     = var.vault_config.vault_endpoint
    vault_namespace    = var.vault_config.vault_namespace
    auth_method        = var.vault_config.auth_method
    enable_transit     = var.vault_config.enable_transit
    transit_mount_path = var.vault_config.transit_mount_path
  } : null
  sensitive = false
}

output "nomad_configuration" {
  description = "Nomad cluster integration configuration"
  value = {
    nomad_endpoint      = var.nomad_config.nomad_endpoint
    nomad_region        = var.nomad_config.nomad_region
    nomad_datacenter    = var.nomad_config.nomad_datacenter
    acl_enabled         = var.nomad_config.acl_enabled
    tls_enabled         = var.nomad_config.tls_enabled
  }
  sensitive = false
}

output "resource_restrictions" {
  description = "Resource access restrictions and quotas"
  value = {
    s3_restrictions = {
      bucket_name = var.aws_config.s3_bucket_name
      restrictions = var.resource_restrictions.s3_bucket_restrictions
    }
    secrets_restrictions = var.resource_restrictions.secrets_restrictions
    github_restrictions  = var.resource_restrictions.github_restrictions
  }
  sensitive = false
}

output "cross_account_configuration" {
  description = "Cross-account access configuration (if enabled)"
  value = var.cross_account_config.enabled ? {
    target_account_ids     = var.cross_account_config.target_account_ids
    target_roles           = var.cross_account_config.target_roles
    assume_role_conditions = var.cross_account_config.assume_role_conditions
    role_arns             = { for k, v in aws_iam_role.cross_account_roles : k => v.arn }
  } : null
  sensitive = false
}