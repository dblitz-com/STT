# Agent Orchestrator Main Configuration
# Implements the Planner + Parallel Workers pattern for AI agent coordination

data "aws_region" "current" {}

# SQS Queue for task distribution
resource "aws_sqs_queue" "agent_task_queue" {
  name                      = "${var.cluster_name}-agent-tasks"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 10

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-task-queue"
    Component   = "agent-orchestrator"
    Environment = var.environment
  })
}

# SQS Queue for task results
resource "aws_sqs_queue" "agent_result_queue" {
  name                      = "${var.cluster_name}-agent-results"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 10

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-result-queue"
    Component   = "agent-orchestrator"
    Environment = var.environment
  })
}

# DynamoDB table for task state management
resource "aws_dynamodb_table" "agent_tasks" {
  name           = "${var.cluster_name}-agent-tasks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "task_id"
  
  attribute {
    name = "task_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "agent_type"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "agent-type-index"
    hash_key        = "agent_type"
    projection_type = "ALL"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-tasks"
    Component   = "agent-orchestrator"
    Environment = var.environment
  })
}

# IAM role for agent operations
resource "aws_iam_role" "agent_role" {
  name = "${var.cluster_name}-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-agent-role"
    Component   = "agent-orchestrator"
    Environment = var.environment
  })
}

# IAM policy for agent operations
resource "aws_iam_role_policy" "agent_policy" {
  name = "${var.cluster_name}-agent-policy"
  role = aws_iam_role.agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.agent_task_queue.arn,
          aws_sqs_queue.agent_result_queue.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.agent_tasks.arn,
          "${aws_dynamodb_table.agent_tasks.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.github_private_key_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:*:*"
      }
    ]
  })
}

# Nomad job specification for the agent coordinator
resource "local_file" "coordinator_job" {
  filename = "${path.module}/jobs/coordinator.nomad"
  content = templatefile("${path.module}/templates/coordinator.nomad.tpl", {
    job_name              = "${var.cluster_name}-agent-coordinator"
    image                 = var.agent_coordinator_image
    cpu_limit             = var.coordinator_cpu_limit
    memory_limit          = var.coordinator_memory_limit
    task_queue_url        = aws_sqs_queue.agent_task_queue.url
    result_queue_url      = aws_sqs_queue.agent_result_queue.url
    task_table_name       = aws_dynamodb_table.agent_tasks.name
    webhook_url           = var.webhook_url
    github_app_id         = var.github_app_id
    github_installation_id = var.github_installation_id
    github_private_key_secret_arn = var.github_private_key_secret_arn
    aws_region            = data.aws_region.current.name
    agent_role_arn        = aws_iam_role.agent_role.arn
    task_timeout          = var.agent_timeout
    environment           = var.environment
    vpc_id                = var.vpc_id
    subnet_ids            = jsonencode(var.subnet_ids)
    security_group_ids    = jsonencode(var.security_group_ids)
  })
}

# Nomad job specifications for each agent type
resource "local_file" "agent_jobs" {
  for_each = var.agent_types
  
  filename = "${path.module}/jobs/${each.key}-agent.nomad"
  content = templatefile("${path.module}/templates/agent.nomad.tpl", {
    job_name              = "${var.cluster_name}-${each.key}-agent"
    agent_type            = each.key
    image                 = each.value.image
    cpu_limit             = each.value.cpu_limit
    memory_limit          = each.value.memory_limit
    max_instances         = each.value.max_instances
    capabilities          = jsonencode(each.value.capabilities)
    env_vars              = each.value.env_vars
    task_queue_url        = aws_sqs_queue.agent_task_queue.url
    result_queue_url      = aws_sqs_queue.agent_result_queue.url
    task_table_name       = aws_dynamodb_table.agent_tasks.name
    github_app_id         = var.github_app_id
    github_installation_id = var.github_installation_id
    github_private_key_secret_arn = var.github_private_key_secret_arn
    aws_region            = data.aws_region.current.name
    agent_role_arn        = aws_iam_role.agent_role.arn
    task_timeout          = var.agent_timeout
    environment           = var.environment
    vpc_id                = var.vpc_id
    subnet_ids            = jsonencode(var.subnet_ids)
    security_group_ids    = jsonencode(var.security_group_ids)
  })
}