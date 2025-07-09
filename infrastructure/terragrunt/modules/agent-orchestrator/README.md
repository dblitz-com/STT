# Agent Orchestrator Module

A Terragrunt module for orchestrating AI coding agents using the **Planner + Parallel Workers** pattern. This module provides production-ready infrastructure for autonomous coding agents that can handle GitHub issues, create branches, write code, and submit pull requests.

## Architecture

This module implements a scalable agent orchestration system with the following components:

```
┌─────────────────────────────────────────────────────────────┐
│                    Agent Orchestrator                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Coordinator   │    │ Task Queue  │    │Result Queue │  │
│  │   (Planner)     │◄──►│    (SQS)    │◄──►│   (SQS)     │  │
│  └─────────────────┘    └─────────────┘    └─────────────┘  │
│           │                     │                   │       │
│           ▼                     ▼                   ▼       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              DynamoDB Task State Table               │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                      Worker Agents                         │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐            │
│ │ Coder   │ │ Tester  │ │Reviewer │ │  Docs   │            │
│ │ Agent   │ │ Agent   │ │ Agent   │ │ Agent   │            │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

- **Scalable Agent Management**: Dynamic scaling based on queue depth
- **Task Distribution**: SQS-based task queue with automatic retry logic
- **State Management**: DynamoDB for persistent task state tracking
- **GitHub Integration**: Native GitHub App authentication for repository access
- **Security**: IAM-based permissions with least-privilege access
- **Monitoring**: Built-in health checks and metrics endpoints
- **Sandboxing**: Container-based isolation for agent execution

## Agent Types

| Agent Type | Purpose | Capabilities | Resource Limits |
|------------|---------|--------------|-----------------|
| **Coder** | Write and modify code | Python, TypeScript, JavaScript, Rust | 1 CPU, 2GB RAM |
| **Tester** | Generate and run tests | Unit, Integration, E2E testing | 0.5 CPU, 1GB RAM |
| **Reviewer** | Code review and auditing | Code review, Security audit, Performance | 0.5 CPU, 1GB RAM |
| **Docs** | Documentation generation | README, API docs, Documentation | 0.3 CPU, 512MB RAM |

## Usage

### Basic Configuration

```hcl
# agent-orchestrator/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/agent-orchestrator"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "nomad_cluster" {
  config_path = "../nomad-cluster"
}

inputs = {
  cluster_name         = "gengine-dev"
  environment          = "development"
  vpc_id              = dependency.vpc.outputs.vpc_id
  subnet_ids          = dependency.vpc.outputs.private_subnet_ids
  security_group_ids  = [dependency.nomad_cluster.outputs.agent_security_group_id]
  
  webhook_url                    = "https://webhook.dev.gengine.com"
  github_app_id                 = "1529272"
  github_installation_id        = "74523281"
  github_private_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789:secret:github-app-key"
  
  agent_types = {
    coder = {
      image          = "ghcr.io/gengine/coder-agent:latest"
      cpu_limit      = 1000
      memory_limit   = "2GB"
      max_instances  = 5
      capabilities   = ["python", "typescript", "javascript", "rust"]
      env_vars       = {
        LOG_LEVEL = "INFO"
      }
    }
    tester = {
      image          = "ghcr.io/gengine/tester-agent:latest"
      cpu_limit      = 500
      memory_limit   = "1GB"
      max_instances  = 3
      capabilities   = ["unit-testing", "integration-testing"]
      env_vars       = {
        TEST_TIMEOUT = "300"
      }
    }
  }
}
```

### Advanced Configuration

```hcl
inputs = {
  # Custom resource limits
  coordinator_cpu_limit    = 1500
  coordinator_memory_limit = "3GB"
  
  # Task management
  task_queue_size = 200
  agent_timeout   = 7200  # 2 hours
  
  # Custom agent configuration
  agent_types = {
    senior_coder = {
      image          = "ghcr.io/gengine/senior-coder-agent:latest"
      cpu_limit      = 2000
      memory_limit   = "4GB"
      max_instances  = 2
      capabilities   = ["python", "typescript", "rust", "architecture", "performance"]
      env_vars       = {
        MODEL_SIZE     = "large"
        COMPLEXITY_MAX = "high"
      }
    }
    security_reviewer = {
      image          = "ghcr.io/gengine/security-agent:latest"
      cpu_limit      = 1000
      memory_limit   = "2GB"
      max_instances  = 1
      capabilities   = ["security-audit", "vulnerability-scan", "compliance"]
      env_vars       = {
        SCAN_LEVEL = "comprehensive"
      }
    }
  }
}
```

## Integration with Existing Infrastructure

### Webhook Integration

The module integrates with your existing webhook server by:

1. **GitHub Event Processing**: Webhook receives GitHub issues/PRs
2. **Task Creation**: Coordinator creates tasks in SQS queue
3. **Agent Assignment**: Agents poll queue based on capabilities
4. **Result Reporting**: Agents report results via result queue

### Nomad Integration

Deploy the generated job files to your Nomad cluster:

```bash
# Deploy coordinator
nomad job run infrastructure/terragrunt/modules/agent-orchestrator/jobs/coordinator.nomad

# Deploy agents
nomad job run infrastructure/terragrunt/modules/agent-orchestrator/jobs/coder-agent.nomad
nomad job run infrastructure/terragrunt/modules/agent-orchestrator/jobs/tester-agent.nomad
```

### Monitoring and Observability

- **Health Checks**: Built-in HTTP health endpoints
- **Metrics**: Prometheus-compatible metrics on port 9090
- **Logging**: Structured JSON logs via journald
- **Service Discovery**: Consul service registration

## Security Considerations

### IAM Permissions

The module creates least-privilege IAM roles with access to:
- SQS queues for task distribution
- DynamoDB for state management
- Secrets Manager for GitHub App credentials
- CloudWatch Logs for logging

### Container Security

- **Resource Limits**: CPU and memory constraints per agent
- **Capability Dropping**: Minimal Linux capabilities
- **Temporary Filesystems**: Isolated temporary storage
- **Network Isolation**: VPC-based network segmentation

### GitHub Integration

- **App-based Authentication**: GitHub App with limited repository access
- **Scoped Permissions**: Read repositories, write pull requests, manage issues
- **Secret Management**: Private keys stored in AWS Secrets Manager

## Outputs

The module provides outputs for integration with other systems:

```hcl
# Access task queue
task_queue_url = module.agent_orchestrator.task_queue_url

# Monitor agent status
task_table_name = module.agent_orchestrator.task_table_name

# Deploy Nomad jobs
coordinator_job = module.agent_orchestrator.coordinator_job_file
agent_jobs      = module.agent_orchestrator.agent_job_files
```

## Scaling

### Horizontal Scaling

Agents automatically scale based on:
- Queue depth metrics
- Task completion rates
- Resource utilization

### Vertical Scaling

Adjust resource limits per agent type:
```hcl
agent_types = {
  high_performance_coder = {
    cpu_limit    = 4000  # 4 CPUs
    memory_limit = "8GB" # 8GB RAM
  }
}
```

## Troubleshooting

### Common Issues

1. **Agents Not Starting**: Check IAM permissions and Nomad job status
2. **Tasks Not Processing**: Verify SQS queue permissions and connectivity
3. **GitHub Integration Failing**: Validate GitHub App configuration and secrets

### Debugging Commands

```bash
# Check Nomad job status
nomad job status gengine-dev-agent-coordinator

# View agent logs
nomad alloc logs <allocation-id>

# Monitor task queue
aws sqs get-queue-attributes --queue-url <queue-url> --attribute-names All

# Check task state
aws dynamodb scan --table-name gengine-dev-agent-tasks
```

## Contributing

When extending this module:

1. **Follow Terragrunt Patterns**: Use includes, dependencies, and units
2. **Maintain Security**: Apply least-privilege principles
3. **Test Scaling**: Verify behavior under load
4. **Document Changes**: Update this README and variable descriptions