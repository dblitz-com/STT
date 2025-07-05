job "mcp-server-[[.job_id]]" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 70

  group "mcp" {
    count = 1

    network {
      mode = "bridge"
      
      port "mcp" {
        to = 8080
      }
    }

    service {
      name = "mcp-server-[[.server_name]]"
      port = "mcp"
      
      tags = [
        "mcp",
        "generated",
        "job-[[.job_id]]",
        "server-[[.server_name]]",
      ]

      # Health checks for MCP server
      check {
        type     = "tcp"
        interval = "15s"
        timeout  = "5s"
      }

      # Service mesh integration with upstream to REST API
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "gengine-rest-api"
              local_bind_port  = 8000
            }
          }
        }
      }
    }

    # Restart policy
    restart {
      attempts = 2
      interval = "10m"
      delay    = "10s"
      mode     = "fail"
    }

    # Auto-scaling configuration
    scaling {
      enabled = true
      min     = 1
      max     = 3

      policy {
        cooldown            = "1m"
        evaluation_interval = "30s"

        check "cpu_usage" {
          source = "nomad-apm"
          query  = "avg_cpu"

          strategy "target-value" {
            target = 70
          }
        }
      }
    }

    task "mcp-server" {
      driver = "docker"

      config {
        image = "python:3.11-slim"
        ports = ["mcp"]
        
        # Mount the generated MCP server code
        volumes = [
          "local/mcp_server.py:/app/mcp_server.py:ro",
          "local/requirements.txt:/app/requirements.txt:ro"
        ]
        
        workdir = "/app"
        command = ["python", "-m", "pip", "install", "-r", "requirements.txt", "&&", "python", "mcp_server.py"]
        entrypoint = ["/bin/bash", "-c"]
      }

      # Resource allocation based on expected load
      resources {
        cpu    = 200
        memory = 256
      }

      # Environment variables for MCP server
      env {
        # Connection to REST API via service mesh
        API_BASE_URL = "http://${NOMAD_UPSTREAM_ADDR_gengine_rest_api}"
        
        # Server configuration
        MCP_SERVER_NAME = "[[.server_name]]"
        JOB_ID          = "[[.job_id]]"
        
        # Logging
        LOG_LEVEL = "INFO"
        
        # Service discovery
        CONSUL_HOST = "${NOMAD_IP_mcp}"
      }

      # Dynamic template for MCP server code
      template {
        data = <<EOF
[[.mcp_server_code]]
EOF
        destination = "local/mcp_server.py"
        change_mode = "restart"
      }

      # Requirements template
      template {
        data = <<EOF
fastapi>=0.104.1
uvicorn>=0.24.0
requests>=2.31.0
mcp>=1.0.0
pydantic>=2.5.0
EOF
        destination = "local/requirements.txt"
        change_mode = "restart"
      }

      # Lifecycle configuration
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      # Health monitoring
      logs {
        max_files     = 3
        max_file_size = 5
      }
    }
  }

  # Automatic cleanup after job completion
  meta {
    "cleanup_after"   = "24h"
    "generated_from"  = "gengine-rest-api"
    "conversion_job"  = "[[.job_id]]"
    "repository_url"  = "[[.git_url]]"
  }
}

# Lifecycle management for generated MCP servers
reschedule {
  attempts       = 1
  interval       = "5m"
  delay          = "10s"
  delay_function = "exponential"
  max_delay      = "1m"
  unlimited      = false
}