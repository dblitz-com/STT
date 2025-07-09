# Agent Orchestrator Module Variables
# Defines variables for the central agent coordination system

variable "cluster_name" {
  description = "Name of the Nomad cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "agent_types" {
  description = "Map of agent types and their configurations"
  type = map(object({
    image          = string
    cpu_limit      = number
    memory_limit   = string
    max_instances  = number
    capabilities   = list(string)
    env_vars       = map(string)
  }))
  default = {
    coder = {
      image          = "ghcr.io/gengine/coder-agent:latest"
      cpu_limit      = 1000
      memory_limit   = "2GB"
      max_instances  = 5
      capabilities   = ["python", "typescript", "javascript", "rust"]
      env_vars       = {}
    }
    tester = {
      image          = "ghcr.io/gengine/tester-agent:latest"
      cpu_limit      = 500
      memory_limit   = "1GB"
      max_instances  = 3
      capabilities   = ["unit-testing", "integration-testing", "e2e-testing"]
      env_vars       = {}
    }
    reviewer = {
      image          = "ghcr.io/gengine/reviewer-agent:latest"
      cpu_limit      = 500
      memory_limit   = "1GB"
      max_instances  = 2
      capabilities   = ["code-review", "security-audit", "performance-review"]
      env_vars       = {}
    }
    docs = {
      image          = "ghcr.io/gengine/docs-agent:latest"
      cpu_limit      = 300
      memory_limit   = "512MB"
      max_instances  = 2
      capabilities   = ["documentation", "readme", "api-docs"]
      env_vars       = {}
    }
  }
}

variable "webhook_url" {
  description = "Base URL for webhook notifications"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID for agent authentication"
  type        = string
}

variable "github_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
}

variable "github_private_key_secret_arn" {
  description = "AWS Secrets Manager ARN containing GitHub App private key"
  type        = string
}

variable "agent_coordinator_image" {
  description = "Docker image for the central agent coordinator"
  type        = string
  default     = "ghcr.io/gengine/agent-coordinator:latest"
}

variable "coordinator_cpu_limit" {
  description = "CPU limit for coordinator in MHz"
  type        = number
  default     = 1000
}

variable "coordinator_memory_limit" {
  description = "Memory limit for coordinator"
  type        = string
  default     = "2GB"
}

variable "task_queue_size" {
  description = "Maximum number of tasks in queue"
  type        = number
  default     = 100
}

variable "agent_timeout" {
  description = "Timeout for agent tasks in seconds"
  type        = number
  default     = 3600
}

variable "vpc_id" {
  description = "VPC ID for agent networking"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for agent deployment"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for agent networking"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}