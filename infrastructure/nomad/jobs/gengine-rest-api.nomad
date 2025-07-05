job "gengine-rest-api" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 80

  group "api" {
    count = 2

    # Load balancing with Consul Connect
    network {
      mode = "bridge"
      
      port "http" {
        static = 8000
        to     = 8000
      }
    }

    service {
      name = "gengine-rest-api"
      port = "http"
      
      tags = [
        "api",
        "mcp-converter",
        "http",
        "urlprefix-/api strip=/api",
      ]

      # Health checks
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
      }

      # Service mesh integration
      connect {
        sidecar_service {
          proxy {
            # Consul Connect configuration for secure service-to-service communication
          }
        }
      }
    }

    # Restart policy for high availability
    restart {
      attempts = 3
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    # Update strategy for zero-downtime deployments
    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      canary           = 1
      auto_revert      = true
    }

    task "gengine-rest-api" {
      driver = "docker"

      config {
        image = "${gengine_image}:${gengine_tag}"
        ports = ["http"]
        
        # Resource constraints
        memory_hard_limit = 1024
        
        # Environment variables
        command = ["python", "-m", "uvicorn", "api.main:app"]
        args    = ["--host", "0.0.0.0", "--port", "8000"]
      }

      # Resource allocation
      resources {
        cpu    = 500
        memory = 512
      }

      # Environment variables
      env {
        ENVIRONMENT = "${environment}"
        LOG_LEVEL   = "${log_level}"
        
        # Service discovery
        CONSUL_HOST = "${NOMAD_IP_http}"
        NOMAD_ADDR  = "http://${attr.nomad.advertise.address}:4646"
      }

      # Volume mounts for workspace persistence
      volume_mount {
        volume      = "workspace"
        destination = "/app/workspace"
        read_only   = false
      }

      # Health monitoring
      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    # Persistent workspace volume
    volume "workspace" {
      type            = "csi"
      source          = "gengine-workspace"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }
  }

  # Parameterized variables for flexible deployment
  parameterized {
    payload       = "forbidden"
    meta_required = ["gengine_image", "gengine_tag", "environment"]
  }
}

# Variable definitions
variable "gengine_image" {
  description = "Docker image for the GenEngine REST API"
  type        = string
  default     = "gengine-rest-api"
}

variable "gengine_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}