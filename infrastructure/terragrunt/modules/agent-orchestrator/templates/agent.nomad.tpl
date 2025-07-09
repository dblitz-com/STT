# Agent Worker Job - Implements the "Workers" pattern
# Executes tasks assigned by the coordinator

job "${job_name}" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  priority    = 70

  group "${agent_type}-agents" {
    count = ${max_instances}

    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
      auto_revert      = true
      canary           = 1
    }

    # Scaling configuration for dynamic agent allocation
    scaling {
      enabled = true
      min     = 1
      max     = ${max_instances}
      
      policy {
        cooldown            = "1m"
        evaluation_interval = "30s"

        check "queue_depth" {
          source = "sqs"
          query  = "queue_depth"
          
          strategy "target-value" {
            target = 5.0
          }
        }
      }
    }

    network {
      port "metrics" {}
    }

    service {
      name = "${agent_type}-agent"
      port = "metrics"
      
      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "10s"
      }

      tags = [
        "agent-worker",
        "agent-type-${agent_type}",
        "environment-${environment}",
        "capabilities-${capabilities}",
        "version-1.0.0"
      ]
    }

    task "${agent_type}-agent" {
      driver = "docker"

      config {
        image = "${image}"
        ports = ["metrics"]
        
        # Agent worker configuration
        args = [
          "--mode=worker",
          "--agent-type=${agent_type}",
          "--capabilities=${capabilities}",
          "--task-queue-url=${task_queue_url}",
          "--result-queue-url=${result_queue_url}",
          "--task-table=${task_table_name}",
          "--github-app-id=${github_app_id}",
          "--github-installation-id=${github_installation_id}",
          "--task-timeout=${task_timeout}",
          "--environment=${environment}"
        ]

        # Resource limits for sandboxing
        ulimit {
          nofile = "1024:1024"
          nproc  = "1024:1024"
        }

        # Security configuration
        cap_drop = ["ALL"]
        cap_add  = ["CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]

        # Temporary filesystem for agent operations
        tmpfs = [
          "/tmp:noexec,nosuid,size=1G"
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "${job_name}-${agent_type}"
          }
        }
      }

      env {
        AGENT_TYPE = "${agent_type}"
        CAPABILITIES = "${capabilities}"
        AWS_REGION = "${aws_region}"
        GITHUB_APP_ID = "${github_app_id}"
        GITHUB_INSTALLATION_ID = "${github_installation_id}"
        GITHUB_PRIVATE_KEY_SECRET_ARN = "${github_private_key_secret_arn}"
        TASK_QUEUE_URL = "${task_queue_url}"
        RESULT_QUEUE_URL = "${result_queue_url}"
        TASK_TABLE_NAME = "${task_table_name}"
        TASK_TIMEOUT = "${task_timeout}"
        ENVIRONMENT = "${environment}"
        VPC_ID = "${vpc_id}"
        SUBNET_IDS = "${subnet_ids}"
        SECURITY_GROUP_IDS = "${security_group_ids}"
        
        # Agent-specific environment variables
        %{ for key, value in env_vars ~}
        ${key} = "${value}"
        %{ endfor ~}
      }

      # Resource allocation based on agent type
      resources {
        cpu    = ${cpu_limit}
        memory = "${memory_limit}"
        
        # Disk allocation for temporary operations
        disk = 1000
      }

      # Task identity and permissions
      vault {
        policies = ["agent-worker", "agent-${agent_type}"]
      }

      # Artifact management for agent code
      artifact {
        source      = "git::https://github.com/dblitz-com/gengine.git//src/agents/${agent_type}"
        destination = "local/agent-code"
        mode        = "dir"
      }
    }
  }
}