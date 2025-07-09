# Agent Sandbox Orchestration Job
# Manages secure, isolated execution environments for AI agents

job "${cluster_name}-sandbox-orchestrator" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "system"
  priority    = 80

  group "sandbox-manager" {
    count = 1

    restart {
      attempts = 5
      interval = "10m"
      delay    = "25s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "30s"
      healthy_deadline = "10m"
      auto_revert      = true
    }

    network {
      port "api" {}
      port "metrics" {}
    }

    service {
      name = "${cluster_name}-sandbox-manager"
      port = "api"
      
      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "10s"
      }

      tags = [
        "sandbox-orchestrator",
        "environment-${environment}",
        "version-1.0.0"
      ]
    }

    # Storage volumes for sandbox persistence
    %{ if length(persistent_volumes) > 0 ~}
    %{ for volume_name, volume_config in persistent_volumes ~}
    volume "${volume_name}" {
      type            = "csi"
      source          = "${cluster_name}-${volume_name}"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
      read_only       = ${volume_config.read_only}
    }
    %{ endfor ~}
    %{ endif ~}

    # Shared storage volume (EFS)
    %{ if shared_storage_enabled ~}
    volume "shared_storage" {
      type            = "csi"
      source          = "${efs_file_system_id}"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
      read_only       = false
    }
    %{ endif ~}

    task "sandbox-orchestrator" {
      driver = "docker"

      config {
        image = "${base_image}"
        ports = ["api", "metrics"]
        
        args = [
          "--mode=orchestrator",
          "--listen-address=0.0.0.0:$${NOMAD_PORT_api}",
          "--metrics-address=0.0.0.0:$${NOMAD_PORT_metrics}",
          "--cluster-name=${cluster_name}",
          "--environment=${environment}",
          "--aws-region=${aws_region}",
          "--log-level=${log_level}"
        ]

        # Security hardening
        cap_drop = ["ALL"]
        cap_add  = ["CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID", "NET_BIND_SERVICE"]
        
        # Resource limits
        ulimit {
          nofile = "${max_open_files}:${max_open_files}"
          nproc  = "${max_processes}:${max_processes}"
        }

        # Temporary filesystem restrictions
        tmpfs = [
          "/tmp:noexec,nosuid,size=${ephemeral_storage}"
        ]

        # Security policies
        %{ if enable_seccomp ~}
        seccomp_profile = "/etc/seccomp/agent-sandbox.json"
        %{ endif ~}

        %{ if enable_apparmor ~}
        security_opt = ["apparmor:agent-sandbox"]
        %{ endif ~}

        # Logging configuration
        logging {
          type = "awslogs"
          config {
            awslogs-group  = "${log_group_name}"
            awslogs-region = "${aws_region}"
            awslogs-stream-prefix = "sandbox-orchestrator"
          }
        }
      }

      # Environment configuration
      env {
        AWS_REGION = "${aws_region}"
        CLUSTER_NAME = "${cluster_name}"
        ENVIRONMENT = "${environment}"
        
        # Security configuration
        MAX_PROCESSES = "${max_processes}"
        MAX_OPEN_FILES = "${max_open_files}"
        ALLOWED_SYSCALLS = "${allowed_syscalls}"
        BLOCKED_SYSCALLS = "${blocked_syscalls}"
        ENABLE_SECCOMP = "${enable_seccomp}"
        ENABLE_APPARMOR = "${enable_apparmor}"
        
        # Network security
        ALLOWED_DOMAINS = "${allowed_domains}"
        BLOCKED_DOMAINS = "${blocked_domains}"
        ENABLE_INTERNET = "${enable_internet}"
        VPC_ID = "${vpc_id}"
        SUBNET_IDS = "${subnet_ids}"
        SECURITY_GROUP_ID = "${security_group_id}"
        
        # Storage configuration
        EPHEMERAL_STORAGE = "${ephemeral_storage}"
        SHARED_STORAGE_ENABLED = "${shared_storage_enabled}"
        %{ if shared_storage_enabled ~}
        EFS_FILE_SYSTEM_ID = "${efs_file_system_id}"
        %{ endif ~}
        
        # Monitoring
        ENABLE_METRICS = "${enable_metrics}"
        METRICS_INTERVAL = "${metrics_interval}"
        LOG_LEVEL = "${log_level}"
        LOG_GROUP_NAME = "${log_group_name}"
        
        # Cleanup configuration
        MAX_EXECUTION_TIME = "${max_execution_time}"
        AUTO_CLEANUP_ENABLED = "${auto_cleanup_enabled}"
        CLEANUP_INTERVAL = "${cleanup_interval}"
        MAX_IDLE_TIME = "${max_idle_time}"
        
        # GitHub integration
        GITHUB_APP_ID = "${github_app_id}"
        GITHUB_INSTALLATION_ID = "${github_installation_id}"
        GITHUB_PRIVATE_KEY_SECRET_ARN = "${github_private_key_secret_arn}"
        WEBHOOK_URL = "${webhook_url}"
        
        # IAM role for sandbox operations
        AWS_ROLE_ARN = "${execution_role_arn}"
      }

      # Resource allocation
      resources {
        cpu    = 1000
        memory = "2GB"
        disk   = 2000
      }

      # Volume mounts for persistent storage
      %{ if length(persistent_volumes) > 0 ~}
      %{ for volume_name, volume_config in persistent_volumes ~}
      volume_mount {
        volume      = "${volume_name}"
        destination = "${volume_config.mount_path}"
        read_only   = ${volume_config.read_only}
      }
      %{ endfor ~}
      %{ endif ~}

      # Shared storage mount
      %{ if shared_storage_enabled ~}
      volume_mount {
        volume      = "shared_storage"
        destination = "/var/shared"
        read_only   = false
      }
      %{ endif ~}

      # Vault integration for secrets
      vault {
        policies = ["sandbox-orchestrator", "github-integration"]
      }

      # Health check and lifecycle
      service {
        name = "sandbox-orchestrator-health"
        port = "api"
        
        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Resource quota enforcement per agent type
  %{ for agent_type, quota in resource_quotas ~}
  group "${agent_type}-sandbox" {
    count = 0  # Dynamically scaled by orchestrator

    constraint {
      attribute = "$${node.class}"
      value     = "agent-worker"
    }

    restart {
      attempts = 2
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "2m"
      auto_revert      = true
    }

    # Ephemeral disk for sandbox operations
    ephemeral_disk {
      size    = ${quota.disk_limit}
      migrate = false
      sticky  = false
    }

    network {
      # Restricted network access based on security policies
      %{ if enable_internet ~}
      mode = "bridge"
      %{ else ~}
      mode = "host"
      %{ endif ~}
    }

    task "${agent_type}-sandbox" {
      driver = "docker"

      config {
        image = "${base_image}"
        
        # Agent-specific command
        command = "/usr/local/bin/agent-runner"
        args = [
          "--agent-type=${agent_type}",
          "--max-runtime=${quota.max_runtime}",
          "--workspace=/tmp/workspace"
        ]

        # Strict resource limits
        cpu_hard_limit = true
        memory_hard_limit = true
        
        # Security restrictions
        cap_drop = ["ALL"]
        cap_add  = ["CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        
        # Process limits
        ulimit {
          nofile = "${max_open_files}:${max_open_files}"
          nproc  = "${max_processes}:${max_processes}"
        }

        # Filesystem restrictions
        tmpfs = [
          "/tmp:noexec,nosuid,size=${ephemeral_storage}",
          "/var/tmp:noexec,nosuid,size=100M"
        ]

        # Network restrictions
        %{ if !enable_internet ~}
        network_mode = "none"
        %{ endif ~}

        # Security profiles
        %{ if enable_seccomp ~}
        seccomp_profile = "/etc/seccomp/agent-${agent_type}.json"
        %{ endif ~}

        %{ if enable_apparmor ~}
        security_opt = ["apparmor:agent-${agent_type}"]
        %{ endif ~}

        # Logging
        logging {
          type = "awslogs"
          config {
            awslogs-group  = "${log_group_name}"
            awslogs-region = "${aws_region}"
            awslogs-stream-prefix = "${agent_type}-sandbox"
          }
        }
      }

      # Agent type specific environment
      env {
        AGENT_TYPE = "${agent_type}"
        MAX_RUNTIME = "${quota.max_runtime}"
        CPU_LIMIT = "${quota.cpu_limit}"
        MEMORY_LIMIT = "${quota.memory_limit}"
        DISK_LIMIT = "${quota.disk_limit}"
        
        # Workspace configuration
        WORKSPACE_PATH = "/tmp/workspace"
        CACHE_PATH = "/var/cache/agent"
        
        # Security environment
        ALLOWED_SYSCALLS = "${allowed_syscalls}"
        BLOCKED_SYSCALLS = "${blocked_syscalls}"
        ALLOWED_DOMAINS = "${allowed_domains}"
        BLOCKED_DOMAINS = "${blocked_domains}"
        
        # GitHub configuration
        GITHUB_APP_ID = "${github_app_id}"
        GITHUB_INSTALLATION_ID = "${github_installation_id}"
        GITHUB_PRIVATE_KEY_SECRET_ARN = "${github_private_key_secret_arn}"
      }

      # Resource allocation per agent type
      resources {
        cpu    = ${quota.cpu_limit}
        memory = "${quota.memory_limit}"
        
        %{ if quota.gpu_limit > 0 ~}
        device "nvidia/gpu" {
          count = ${quota.gpu_limit}
        }
        %{ endif ~}
      }

      # Lifecycle management
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"

      # Cleanup on task completion
      lifecycle {
        hook    = "poststop"
        sidecar = false
      }
    }
  }
  %{ endfor ~}

  # Periodic cleanup job
  %{ if auto_cleanup_enabled ~}
  periodic {
    cron             = "*/${cleanup_interval} * * * *"
    prohibit_overlap = true
    time_zone        = "UTC"
  }

  group "cleanup" {
    count = 1

    task "sandbox-cleanup" {
      driver = "docker"

      config {
        image = "${base_image}"
        
        command = "/usr/local/bin/sandbox-cleaner"
        args = [
          "--max-idle-time=${max_idle_time}",
          "--cluster-name=${cluster_name}",
          "--environment=${environment}"
        ]
      }

      env {
        AWS_REGION = "${aws_region}"
        CLUSTER_NAME = "${cluster_name}"
        ENVIRONMENT = "${environment}"
        MAX_IDLE_TIME = "${max_idle_time}"
        LOG_GROUP_NAME = "${log_group_name}"
      }

      resources {
        cpu    = 100
        memory = "128MB"
      }
    }
  }
  %{ endif ~}
}