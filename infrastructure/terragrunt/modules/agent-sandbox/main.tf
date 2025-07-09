# Agent Sandbox Main Configuration
# Provides secure, isolated execution environments for AI agents

data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for Agent Sandboxes
resource "aws_security_group" "agent_sandbox" {
  name_prefix = "${var.cluster_name}-agent-sandbox-"
  vpc_id      = var.network_config.vpc_id

  # Ingress rules for allowed ports
  dynamic "ingress" {
    for_each = var.network_config.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Allowed port ${ingress.value} for agent communication"
    }
  }

  # Egress rules - conditional internet access
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.sandbox_config.enable_internet ? ["0.0.0.0/0"] : ["10.0.0.0/8"]
    description = "HTTPS access for package downloads and API calls"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.sandbox_config.enable_internet ? ["0.0.0.0/0"] : ["10.0.0.0/8"]
    description = "HTTP access for package downloads"
  }

  # DNS access
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }

  # Internal communication
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Internal VPC communication"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-sandbox-sg"
    Component   = "agent-sandbox"
    Environment = var.environment
  })
}

# EBS Volumes for Persistent Storage
resource "aws_ebs_volume" "agent_persistent_storage" {
  for_each = var.storage_config.persistent_volumes

  availability_zone = data.aws_availability_zones.available.names[0]
  size              = tonumber(regex("^([0-9]+)", each.value.size))
  type              = each.value.type
  encrypted         = true

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-${each.key}"
    Component   = "agent-sandbox"
    Environment = var.environment
    VolumeType  = each.key
  })
}

# EFS for Shared Storage (if enabled)
resource "aws_efs_file_system" "agent_shared_storage" {
  count = var.storage_config.shared_storage.enabled ? 1 : 0

  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  encrypted        = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-shared-storage"
    Component   = "agent-sandbox"
    Environment = var.environment
  })
}

# EFS Mount Targets
resource "aws_efs_mount_target" "agent_shared_storage" {
  count = var.storage_config.shared_storage.enabled ? length(var.network_config.subnet_ids) : 0

  file_system_id  = aws_efs_file_system.agent_shared_storage[0].id
  subnet_id       = var.network_config.subnet_ids[count.index]
  security_groups = [aws_security_group.agent_sandbox.id]
}

# IAM Role for Sandbox Execution
resource "aws_iam_role" "sandbox_execution_role" {
  name = "${var.cluster_name}-sandbox-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-sandbox-execution-role"
    Component   = "agent-sandbox"
    Environment = var.environment
  })
}

# IAM Policy for Sandbox Operations
resource "aws_iam_role_policy" "sandbox_execution_policy" {
  name = "${var.cluster_name}-sandbox-execution-policy"
  role = aws_iam_role.sandbox_execution_role.id

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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:*:log-group:/agent-sandbox/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.integration_config.github_private_key_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DetachVolume"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Component" = "agent-sandbox"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for Sandbox Monitoring
resource "aws_cloudwatch_log_group" "agent_sandbox_logs" {
  name              = "/agent-sandbox/${var.cluster_name}"
  retention_in_days = var.monitoring_config.retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-sandbox-logs"
    Component   = "agent-sandbox"
    Environment = var.environment
  })
}

# CloudWatch Metric Filters for Security Monitoring
resource "aws_cloudwatch_log_metric_filter" "security_violations" {
  name           = "${var.cluster_name}-sandbox-security-violations"
  log_group_name = aws_cloudwatch_log_group.agent_sandbox_logs.name
  pattern        = "[timestamp, level=\"ERROR\", component=\"security\", ...]"

  metric_transformation {
    name      = "SandboxSecurityViolations"
    namespace = "AgentSandbox"
    value     = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "resource_limits_exceeded" {
  name           = "${var.cluster_name}-sandbox-resource-limits"
  log_group_name = aws_cloudwatch_log_group.agent_sandbox_logs.name
  pattern        = "[timestamp, level=\"WARN\", component=\"resource\", event=\"limit_exceeded\", ...]"

  metric_transformation {
    name      = "SandboxResourceLimitsExceeded"
    namespace = "AgentSandbox"
    value     = "1"
    default_value = "0"
  }
}

# CloudWatch Alarms for Security Monitoring
resource "aws_cloudwatch_metric_alarm" "security_violations_alarm" {
  alarm_name          = "${var.cluster_name}-sandbox-security-violations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SandboxSecurityViolations"
  namespace           = "AgentSandbox"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors security violations in agent sandboxes"
  alarm_actions       = []  # Add SNS topic ARN for notifications

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-sandbox-security-alarm"
    Component   = "agent-sandbox"
    Environment = var.environment
  })
}

# Nomad Job Template for Sandbox Orchestration
resource "local_file" "sandbox_job_template" {
  filename = "${path.module}/templates/sandbox.nomad.tpl"
  content = templatefile("${path.module}/templates/sandbox.nomad.tpl", {
    cluster_name           = var.cluster_name
    environment           = var.environment
    base_image            = var.sandbox_config.base_image
    security_group_id     = aws_security_group.agent_sandbox.id
    subnet_ids            = jsonencode(var.network_config.subnet_ids)
    vpc_id                = var.network_config.vpc_id
    execution_role_arn    = aws_iam_role.sandbox_execution_role.arn
    log_group_name        = aws_cloudwatch_log_group.agent_sandbox_logs.name
    
    # Storage configuration
    persistent_volumes    = var.storage_config.persistent_volumes
    ephemeral_storage     = var.sandbox_config.temp_storage_size
    shared_storage_enabled = var.storage_config.shared_storage.enabled
    efs_file_system_id    = var.storage_config.shared_storage.enabled ? aws_efs_file_system.agent_shared_storage[0].id : ""
    
    # Security configuration
    max_processes         = var.security_policies.max_processes
    max_open_files        = var.security_policies.max_open_files
    allowed_syscalls      = jsonencode(var.security_policies.allowed_syscalls)
    blocked_syscalls      = jsonencode(var.security_policies.blocked_syscalls)
    enable_seccomp        = var.security_policies.enable_seccomp
    enable_apparmor       = var.security_policies.enable_apparmor
    
    # Resource quotas by agent type
    resource_quotas       = var.resource_quotas
    
    # Network security
    allowed_domains       = jsonencode(var.security_policies.allowed_domains)
    blocked_domains       = jsonencode(var.security_policies.blocked_domains)
    enable_internet       = var.sandbox_config.enable_internet
    
    # Monitoring
    enable_metrics        = var.monitoring_config.enable_metrics
    metrics_interval      = var.monitoring_config.metrics_interval
    log_level            = var.monitoring_config.log_level
    
    # Cleanup
    max_execution_time    = var.sandbox_config.max_execution_time
    auto_cleanup_enabled  = var.cleanup_config.auto_cleanup_enabled
    cleanup_interval      = var.cleanup_config.cleanup_interval
    max_idle_time        = var.cleanup_config.max_idle_time
    
    # Integration
    github_app_id         = var.integration_config.github_app_id
    github_installation_id = var.integration_config.github_installation_id
    github_private_key_secret_arn = var.integration_config.github_private_key_secret_arn
    webhook_url           = var.integration_config.webhook_url
  })
}

# Create templates directory
resource "local_file" "templates_directory" {
  filename = "${path.module}/templates/.gitkeep"
  content  = "# This directory contains Nomad job templates for agent sandboxes\n"
}