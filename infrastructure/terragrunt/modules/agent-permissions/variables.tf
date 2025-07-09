# Agent Permissions Module Variables
# Defines variables for IAM roles, policies, and permissions management

variable "cluster_name" {
  description = "Name of the Nomad cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "agent_types" {
  description = "Map of agent types and their permission requirements"
  type = map(object({
    github_permissions = list(string)
    aws_permissions    = list(string)
    vault_policies     = list(string)
    resource_access    = list(string)
    cross_account_access = bool
  }))
  default = {
    coder = {
      github_permissions = [
        "contents:read",
        "contents:write", 
        "pull_requests:write",
        "issues:read",
        "metadata:read"
      ]
      aws_permissions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream", 
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue",
        "s3:GetObject",
        "s3:PutObject"
      ]
      vault_policies = ["agent-base", "github-integration", "coder-secrets"]
      resource_access = ["repositories", "pull_requests", "artifacts"]
      cross_account_access = false
    }
    tester = {
      github_permissions = [
        "contents:read",
        "checks:write",
        "statuses:write",
        "issues:read",
        "metadata:read"
      ]
      aws_permissions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents", 
        "secretsmanager:GetSecretValue"
      ]
      vault_policies = ["agent-base", "github-integration", "test-secrets"]
      resource_access = ["repositories", "test_results", "artifacts"]
      cross_account_access = false
    }
    reviewer = {
      github_permissions = [
        "contents:read",
        "pull_requests:read",
        "pull_requests:write",
        "issues:read",
        "metadata:read"
      ]
      aws_permissions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue"
      ]
      vault_policies = ["agent-base", "github-integration"]
      resource_access = ["repositories", "pull_requests"]
      cross_account_access = false
    }
    docs = {
      github_permissions = [
        "contents:read",
        "contents:write",
        "pull_requests:write",
        "metadata:read"
      ]
      aws_permissions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue"
      ]
      vault_policies = ["agent-base", "github-integration"]
      resource_access = ["repositories", "documentation"]
      cross_account_access = false
    }
  }
}

variable "github_app_config" {
  description = "GitHub App configuration for agent authentication"
  type = object({
    app_id                = string
    installation_id       = string
    private_key_secret_arn = string
    webhook_secret_arn    = string
    permissions           = map(string)
  })
}

variable "aws_config" {
  description = "AWS service configuration for agent operations"
  type = object({
    region              = string
    account_id          = string
    vpc_id              = string
    subnet_ids          = list(string)
    s3_bucket_name      = string
    cloudwatch_log_group = string
    secrets_kms_key_arn = string
  })
}

variable "vault_config" {
  description = "HashiCorp Vault integration configuration"
  type = object({
    vault_endpoint      = string
    vault_namespace     = string
    auth_method         = string
    role_id_secret_arn  = string
    secret_id_secret_arn = string
    enable_transit      = bool
    transit_mount_path  = string
  })
  default = {
    vault_endpoint       = ""
    vault_namespace      = ""
    auth_method         = "aws"
    role_id_secret_arn   = ""
    secret_id_secret_arn = ""
    enable_transit      = false
    transit_mount_path  = "transit"
  }
}

variable "nomad_config" {
  description = "Nomad cluster integration configuration"
  type = object({
    nomad_endpoint    = string
    nomad_region      = string
    nomad_datacenter  = string
    acl_enabled       = bool
    tls_enabled       = bool
    ca_cert_secret_arn = string
  })
}

variable "cross_account_config" {
  description = "Cross-account access configuration for multi-environment deployments"
  type = object({
    enabled                = bool
    target_account_ids     = list(string)
    target_roles           = map(string)
    assume_role_conditions = map(list(string))
  })
  default = {
    enabled                = false
    target_account_ids     = []
    target_roles           = {}
    assume_role_conditions = {}
  }
}

variable "security_policies" {
  description = "Security policies and restrictions for agent permissions"
  type = object({
    enforce_mfa                = bool
    require_request_signing    = bool
    ip_restriction_enabled     = bool
    allowed_ip_cidrs           = list(string)
    session_duration_seconds   = number
    external_id_required       = bool
    condition_keys             = map(list(string))
  })
  default = {
    enforce_mfa              = false
    require_request_signing  = true
    ip_restriction_enabled   = true
    allowed_ip_cidrs         = ["10.0.0.0/8"]
    session_duration_seconds = 3600
    external_id_required     = false
    condition_keys           = {}
  }
}

variable "resource_restrictions" {
  description = "Resource-based access restrictions and quotas"
  type = object({
    s3_bucket_restrictions = map(object({
      allowed_prefixes = list(string)
      denied_prefixes  = list(string)
      max_object_size  = number
    }))
    secrets_restrictions = object({
      allowed_secret_patterns = list(string)
      denied_secret_patterns  = list(string)
    })
    github_restrictions = object({
      allowed_repositories = list(string)
      denied_repositories  = list(string)
      max_file_size       = number
      allowed_file_types  = list(string)
    })
  })
  default = {
    s3_bucket_restrictions = {}
    secrets_restrictions = {
      allowed_secret_patterns = ["github-app/*", "agent-config/*"]
      denied_secret_patterns  = ["admin/*", "root/*"]
    }
    github_restrictions = {
      allowed_repositories = []
      denied_repositories  = []
      max_file_size       = 104857600  # 100MB
      allowed_file_types  = [".py", ".js", ".ts", ".md", ".json", ".yaml", ".yml"]
    }
  }
}

variable "monitoring_config" {
  description = "Monitoring and audit configuration for permissions"
  type = object({
    enable_cloudtrail     = bool
    enable_access_logging = bool
    log_retention_days    = number
    enable_alerts         = bool
    alert_sns_topic_arn   = string
  })
  default = {
    enable_cloudtrail     = true
    enable_access_logging = true
    log_retention_days    = 90
    enable_alerts         = true
    alert_sns_topic_arn   = ""
  }
}

variable "integration_roles" {
  description = "External service integration role configuration"
  type = map(object({
    service_name        = string
    trusted_entities    = list(string)
    external_conditions = map(list(string))
    policies            = list(string)
    max_session_duration = number
  }))
  default = {
    webhook_service = {
      service_name         = "webhook-service"
      trusted_entities     = ["ec2.amazonaws.com"]
      external_conditions  = {}
      policies            = ["webhook-basic"]
      max_session_duration = 3600
    }
    coordinator_service = {
      service_name         = "coordinator-service"
      trusted_entities     = ["ecs-tasks.amazonaws.com"]
      external_conditions  = {}
      policies            = ["coordinator-full"]
      max_session_duration = 7200
    }
  }
}

variable "common_tags" {
  description = "Common tags to apply to all IAM resources"
  type        = map(string)
  default     = {}
}