# Agent Coordinator Job - Implements the "Planner" pattern
# Coordinates task allocation and agent lifecycle management

job "${job_name}" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  priority    = 80

  group "coordinator" {
    count = 1

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
    }

    network {
      port "http" {
        static = 8080
      }
      port "metrics" {
        static = 9090
      }
    }

    service {
      name = "${job_name}"
      port = "http"
      
      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "10s"
      }

      tags = [
        "agent-coordinator",
        "environment-${environment}",
        "version-1.0.0"
      ]
    }

    task "coordinator" {
      driver = "docker"

      config {
        image = "${image}"
        ports = ["http", "metrics"]
        
        # Agent coordinator configuration
        args = [
          "--mode=coordinator",
          "--port=8080",
          "--metrics-port=9090",
          "--task-queue-url=${task_queue_url}",
          "--result-queue-url=${result_queue_url}",
          "--task-table=${task_table_name}",
          "--webhook-url=${webhook_url}",
          "--github-app-id=${github_app_id}",
          "--github-installation-id=${github_installation_id}",
          "--task-timeout=${task_timeout}",
          "--environment=${environment}"
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "${job_name}-coordinator"
          }
        }
      }

      env {
        AWS_REGION = "${aws_region}"
        GITHUB_APP_ID = "${github_app_id}"
        GITHUB_INSTALLATION_ID = "${github_installation_id}"
        GITHUB_PRIVATE_KEY_SECRET_ARN = "${github_private_key_secret_arn}"
        TASK_QUEUE_URL = "${task_queue_url}"
        RESULT_QUEUE_URL = "${result_queue_url}"
        TASK_TABLE_NAME = "${task_table_name}"
        WEBHOOK_URL = "${webhook_url}"
        TASK_TIMEOUT = "${task_timeout}"
        ENVIRONMENT = "${environment}"
        VPC_ID = "${vpc_id}"
        SUBNET_IDS = "${subnet_ids}"
        SECURITY_GROUP_IDS = "${security_group_ids}"
      }

      # Resource allocation
      resources {
        cpu    = ${cpu_limit}
        memory = "${memory_limit}"
      }

      # Task identity and permissions
      vault {
        policies = ["agent-coordinator"]
      }
    }
  }
}