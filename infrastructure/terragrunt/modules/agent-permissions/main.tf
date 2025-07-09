# Agent Permissions Main Configuration
# Creates IAM roles, policies, and permissions for AI agent operations

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Base IAM Role for All Agents
resource "aws_iam_role" "agent_base_role" {
  name = "${var.cluster_name}-agent-base-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "ec2.amazonaws.com"
          ]
        }
        Condition = var.security_policies.ip_restriction_enabled ? {
          IpAddress = {
            "aws:SourceIp" = var.security_policies.allowed_ip_cidrs
          }
        } : {}
      }
    ]
  })

  max_session_duration = var.security_policies.session_duration_seconds

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-base-role"
    Component   = "agent-permissions"
    Environment = var.environment
    AgentType   = "base"
  })
}

# Agent Type Specific Roles
resource "aws_iam_role" "agent_type_roles" {
  for_each = var.agent_types

  name = "${var.cluster_name}-${each.key}-agent-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.agent_base_role.arn
        }
        Condition = merge(
          var.security_policies.require_request_signing ? {
            Bool = {
              "aws:SecureTransport" = "true"
            }
          } : {},
          var.security_policies.ip_restriction_enabled ? {
            IpAddress = {
              "aws:SourceIp" = var.security_policies.allowed_ip_cidrs
            }
          } : {},
          var.security_policies.external_id_required ? {
            StringEquals = {
              "sts:ExternalId" = "${var.cluster_name}-${each.key}-agent"
            }
          } : {}
        )
      }
    ]
  })

  max_session_duration = var.security_policies.session_duration_seconds

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-${each.key}-agent-role"
    Component   = "agent-permissions"
    Environment = var.environment
    AgentType   = each.key
  })
}

# Base Agent Policy - Common permissions for all agents
resource "aws_iam_policy" "agent_base_policy" {
  name        = "${var.cluster_name}-agent-base-policy"
  description = "Base permissions for all AI agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.aws_config.cloudwatch_log_group}*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = ["AgentMetrics", "AgentSandbox"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.github_app_config.private_key_secret_arn,
          var.github_app_config.webhook_secret_arn
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-base-policy"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}

# Agent Type Specific Policies
resource "aws_iam_policy" "agent_type_policies" {
  for_each = var.agent_types

  name        = "${var.cluster_name}-${each.key}-agent-policy"
  description = "Specific permissions for ${each.key} agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # AWS service permissions
      [
        {
          Effect   = "Allow"
          Action   = each.value.aws_permissions
          Resource = "*"
          Condition = var.security_policies.condition_keys != {} ? var.security_policies.condition_keys : null
        }
      ],
      # S3 permissions with restrictions
      length(var.resource_restrictions.s3_bucket_restrictions) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            for prefix in lookup(var.resource_restrictions.s3_bucket_restrictions, each.key, {allowed_prefixes = ["${each.key}/*"]}).allowed_prefixes :
            "arn:aws:s3:::${var.aws_config.s3_bucket_name}/${prefix}"
          ]
        }
      ] : [],
      # Secrets Manager permissions with restrictions
      [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = [
            for pattern in var.resource_restrictions.secrets_restrictions.allowed_secret_patterns :
            "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${pattern}"
          ]
        }
      ],
      # Deny restricted secrets
      length(var.resource_restrictions.secrets_restrictions.denied_secret_patterns) > 0 ? [
        {
          Effect = "Deny"
          Action = [
            "secretsmanager:*"
          ]
          Resource = [
            for pattern in var.resource_restrictions.secrets_restrictions.denied_secret_patterns :
            "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${pattern}"
          ]
        }
      ] : []
    )
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-${each.key}-agent-policy"
    Component   = "agent-permissions"
    Environment = var.environment
    AgentType   = each.key
  })
}

# GitHub App Integration Policy
resource "aws_iam_policy" "github_integration_policy" {
  name        = "${var.cluster_name}-github-integration-policy"
  description = "Permissions for GitHub App integration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.github_app_config.private_key_secret_arn,
          var.github_app_config.webhook_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.aws_config.secrets_kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-github-integration-policy"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}

# Vault Integration Policy (if enabled)
resource "aws_iam_policy" "vault_integration_policy" {
  count = var.vault_config.vault_endpoint != "" ? 1 : 0

  name        = "${var.cluster_name}-vault-integration-policy"
  description = "Permissions for HashiCorp Vault integration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.vault_config.role_id_secret_arn,
          var.vault_config.secret_id_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vault-auth-*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-vault-integration-policy"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}

# Cross-Account Access Roles (if enabled)
resource "aws_iam_role" "cross_account_roles" {
  for_each = var.cross_account_config.enabled ? var.cross_account_config.target_roles : {}

  name = "${var.cluster_name}-cross-account-${each.key}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in var.cross_account_config.target_account_ids :
            "arn:aws:iam::${account_id}:root"
          ]
        }
        Condition = merge(
          var.security_policies.external_id_required ? {
            StringEquals = {
              "sts:ExternalId" = "${var.cluster_name}-cross-account"
            }
          } : {},
          lookup(var.cross_account_config.assume_role_conditions, each.key, {})
        )
      }
    ]
  })

  max_session_duration = var.security_policies.session_duration_seconds

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-cross-account-${each.key}"
    Component   = "agent-permissions"
    Environment = var.environment
    CrossAccount = "true"
  })
}

# Integration Service Roles
resource "aws_iam_role" "integration_roles" {
  for_each = var.integration_roles

  name = "${var.cluster_name}-${each.key}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = each.value.trusted_entities
        }
        Condition = each.value.external_conditions
      }
    ]
  })

  max_session_duration = each.value.max_session_duration

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-${each.key}"
    Component   = "agent-permissions"
    Environment = var.environment
    ServiceType = each.value.service_name
  })
}

# Policy Attachments - Base
resource "aws_iam_role_policy_attachment" "agent_base_attachments" {
  role       = aws_iam_role.agent_base_role.name
  policy_arn = aws_iam_policy.agent_base_policy.arn
}

resource "aws_iam_role_policy_attachment" "agent_base_github" {
  role       = aws_iam_role.agent_base_role.name
  policy_arn = aws_iam_policy.github_integration_policy.arn
}

resource "aws_iam_role_policy_attachment" "agent_base_vault" {
  count = var.vault_config.vault_endpoint != "" ? 1 : 0

  role       = aws_iam_role.agent_base_role.name
  policy_arn = aws_iam_policy.vault_integration_policy[0].arn
}

# Policy Attachments - Agent Types
resource "aws_iam_role_policy_attachment" "agent_type_attachments" {
  for_each = var.agent_types

  role       = aws_iam_role.agent_type_roles[each.key].name
  policy_arn = aws_iam_policy.agent_type_policies[each.key].arn
}

resource "aws_iam_role_policy_attachment" "agent_type_base" {
  for_each = var.agent_types

  role       = aws_iam_role.agent_type_roles[each.key].name
  policy_arn = aws_iam_policy.agent_base_policy.arn
}

# CloudTrail for Permission Auditing (if enabled)
resource "aws_cloudtrail" "agent_permissions_trail" {
  count = var.monitoring_config.enable_cloudtrail ? 1 : 0

  name           = "${var.cluster_name}-agent-permissions-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_bucket[0].bucket
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::IAM::Role"
      values = [for role in aws_iam_role.agent_type_roles : role.arn]
    }

    data_resource {
      type   = "AWS::IAM::Policy" 
      values = [for policy in aws_iam_policy.agent_type_policies : policy.arn]
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-permissions-trail"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}

# S3 Bucket for CloudTrail (if enabled)
resource "aws_s3_bucket" "cloudtrail_bucket" {
  count = var.monitoring_config.enable_cloudtrail ? 1 : 0

  bucket        = "${var.cluster_name}-agent-permissions-trail-${random_id.bucket_suffix[0].hex}"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-permissions-trail"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}

resource "random_id" "bucket_suffix" {
  count = var.monitoring_config.enable_cloudtrail ? 1 : 0
  
  byte_length = 4
}

# S3 Bucket Policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  count = var.monitoring_config.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket[0].arn
      }
    ]
  })
}

# CloudWatch Log Group for Access Logs (if enabled)
resource "aws_cloudwatch_log_group" "agent_access_logs" {
  count = var.monitoring_config.enable_access_logging ? 1 : 0

  name              = "/agent-permissions/${var.cluster_name}"
  retention_in_days = var.monitoring_config.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-access-logs"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}

# CloudWatch Metric Filters for Security Monitoring
resource "aws_cloudwatch_log_metric_filter" "unauthorized_access" {
  count = var.monitoring_config.enable_access_logging ? 1 : 0

  name           = "${var.cluster_name}-unauthorized-access"
  log_group_name = aws_cloudwatch_log_group.agent_access_logs[0].name
  pattern        = "[timestamp, level=\"ERROR\", component=\"auth\", event=\"unauthorized\", ...]"

  metric_transformation {
    name      = "UnauthorizedAccess"
    namespace = "AgentPermissions"
    value     = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "permission_escalation" {
  count = var.monitoring_config.enable_access_logging ? 1 : 0

  name           = "${var.cluster_name}-permission-escalation"
  log_group_name = aws_cloudwatch_log_group.agent_access_logs[0].name
  pattern        = "[timestamp, level=\"WARN\", component=\"auth\", event=\"escalation\", ...]"

  metric_transformation {
    name      = "PermissionEscalation"
    namespace = "AgentPermissions"
    value     = "1"
    default_value = "0"
  }
}

# CloudWatch Alarms for Security Events (if enabled)
resource "aws_cloudwatch_metric_alarm" "unauthorized_access_alarm" {
  count = var.monitoring_config.enable_alerts && var.monitoring_config.alert_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${var.cluster_name}-unauthorized-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnauthorizedAccess"
  namespace           = "AgentPermissions"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This metric monitors unauthorized access attempts by agents"
  alarm_actions       = [var.monitoring_config.alert_sns_topic_arn]

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-unauthorized-access-alarm"
    Component   = "agent-permissions"
    Environment = var.environment
  })
}