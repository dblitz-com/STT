# Agent Orchestrator Module Outputs
# Exposes key resources and configuration for integration

output "task_queue_url" {
  description = "SQS URL for agent task distribution"
  value       = aws_sqs_queue.agent_task_queue.url
}

output "task_queue_arn" {
  description = "SQS ARN for agent task distribution"
  value       = aws_sqs_queue.agent_task_queue.arn
}

output "result_queue_url" {
  description = "SQS URL for agent task results"
  value       = aws_sqs_queue.agent_result_queue.url
}

output "result_queue_arn" {
  description = "SQS ARN for agent task results"
  value       = aws_sqs_queue.agent_result_queue.arn
}

output "task_table_name" {
  description = "DynamoDB table name for task state management"
  value       = aws_dynamodb_table.agent_tasks.name
}

output "task_table_arn" {
  description = "DynamoDB table ARN for task state management"
  value       = aws_dynamodb_table.agent_tasks.arn
}

output "agent_role_arn" {
  description = "IAM role ARN for agent operations"
  value       = aws_iam_role.agent_role.arn
}

output "coordinator_job_file" {
  description = "Path to the coordinator Nomad job file"
  value       = local_file.coordinator_job.filename
}

output "agent_job_files" {
  description = "Map of agent type to Nomad job file paths"
  value       = { for k, v in local_file.agent_jobs : k => v.filename }
}

output "agent_types" {
  description = "Configuration of all agent types"
  value       = var.agent_types
}

output "webhook_integration" {
  description = "Webhook configuration for GitHub integration"
  value = {
    webhook_url             = var.webhook_url
    github_app_id          = var.github_app_id
    github_installation_id = var.github_installation_id
  }
  sensitive = false
}

output "orchestrator_endpoints" {
  description = "Key orchestrator service endpoints"
  value = {
    coordinator_service_name = "${var.cluster_name}-agent-coordinator"
    task_queue_url          = aws_sqs_queue.agent_task_queue.url
    result_queue_url        = aws_sqs_queue.agent_result_queue.url
    task_table_name         = aws_dynamodb_table.agent_tasks.name
  }
}

output "scaling_configuration" {
  description = "Agent scaling and resource configuration"
  value = {
    max_instances_per_type = { for k, v in var.agent_types : k => v.max_instances }
    total_max_instances    = sum([for v in var.agent_types : v.max_instances])
    task_queue_size        = var.task_queue_size
    agent_timeout          = var.agent_timeout
  }
}