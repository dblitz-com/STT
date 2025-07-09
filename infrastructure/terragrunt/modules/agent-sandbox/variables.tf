# Agent Sandbox Module Variables
# Defines variables for creating isolated execution environments for agents

variable "cluster_name" {
  description = "Name of the Nomad cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "sandbox_config" {
  description = "Configuration for agent sandbox environments"
  type = object({
    base_image           = string
    cpu_limit_default    = number
    memory_limit_default = string
    disk_limit_default   = number
    network_mode         = string
    enable_internet      = bool
    max_execution_time   = number
    temp_storage_size    = string
  })
  default = {
    base_image           = "ghcr.io/gengine/agent-sandbox:latest"
    cpu_limit_default    = 1000
    memory_limit_default = "1GB"
    disk_limit_default   = 2000
    network_mode         = "bridge"
    enable_internet      = true
    max_execution_time   = 3600
    temp_storage_size    = "1GB"
  }
}

variable "security_policies" {
  description = "Security policies for agent sandboxes"
  type = object({
    allowed_syscalls     = list(string)
    blocked_syscalls     = list(string)
    max_processes        = number
    max_open_files       = number
    allow_network_access = bool
    allowed_domains      = list(string)
    blocked_domains      = list(string)
    enable_seccomp       = bool
    enable_apparmor      = bool
  })
  default = {
    allowed_syscalls = [
      "read", "write", "open", "close", "stat", "fstat", "lstat", "poll",
      "lseek", "mmap", "mprotect", "munmap", "brk", "rt_sigaction",
      "rt_sigprocmask", "rt_sigreturn", "ioctl", "access", "pipe",
      "select", "sched_yield", "mremap", "msync", "mincore", "madvise",
      "dup", "dup2", "getpid", "socket", "connect", "accept", "sendto",
      "recvfrom", "sendmsg", "recvmsg", "shutdown", "bind", "listen",
      "getsockname", "getpeername", "socketpair", "clone", "fork",
      "vfork", "execve", "exit", "wait4", "kill", "uname", "fcntl",
      "flock", "fsync", "fdatasync", "truncate", "ftruncate", "getcwd",
      "chdir", "rename", "mkdir", "rmdir", "creat", "link", "unlink",
      "symlink", "readlink", "chmod", "fchmod", "chown", "fchown",
      "lchown", "umask", "gettimeofday", "getrlimit", "getrusage",
      "sysinfo", "times", "ptrace", "getuid", "syslog", "getgid",
      "setuid", "setgid", "geteuid", "getegid", "setpgid", "getppid"
    ]
    blocked_syscalls = [
      "mount", "umount", "swapon", "swapoff", "reboot", "sethostname",
      "setdomainname", "iopl", "ioperm", "create_module", "init_module",
      "delete_module", "get_kernel_syms", "query_module", "quotactl",
      "nfsservctl", "getpmsg", "putpmsg", "afs_syscall", "tuxcall",
      "security", "gettid", "readahead", "setxattr", "lsetxattr",
      "fsetxattr", "getxattr", "lgetxattr", "fgetxattr", "listxattr",
      "llistxattr", "flistxattr", "removexattr", "lremovexattr",
      "fremovexattr", "tkill", "time", "futex", "sched_setaffinity",
      "sched_getaffinity", "set_thread_area", "io_setup", "io_destroy",
      "io_getevents", "io_submit", "io_cancel", "get_thread_area"
    ]
    max_processes      = 50
    max_open_files     = 1024
    allow_network_access = true
    allowed_domains = [
      "github.com", "api.github.com", "raw.githubusercontent.com",
      "registry.npmjs.org", "pypi.org", "crates.io"
    ]
    blocked_domains = [
      "facebook.com", "twitter.com", "instagram.com", "tiktok.com"
    ]
    enable_seccomp  = true
    enable_apparmor = true
  }
}

variable "resource_quotas" {
  description = "Resource quotas per agent type"
  type = map(object({
    cpu_limit    = number
    memory_limit = string
    disk_limit   = number
    gpu_limit    = number
    max_runtime  = number
  }))
  default = {
    coder = {
      cpu_limit    = 2000
      memory_limit = "4GB"
      disk_limit   = 5000
      gpu_limit    = 0
      max_runtime  = 7200
    }
    tester = {
      cpu_limit    = 1000
      memory_limit = "2GB"
      disk_limit   = 3000
      gpu_limit    = 0
      max_runtime  = 3600
    }
    reviewer = {
      cpu_limit    = 500
      memory_limit = "1GB"
      disk_limit   = 1000
      gpu_limit    = 0
      max_runtime  = 1800
    }
    docs = {
      cpu_limit    = 300
      memory_limit = "512MB"
      disk_limit   = 500
      gpu_limit    = 0
      max_runtime  = 900
    }
  }
}

variable "storage_config" {
  description = "Storage configuration for agent sandboxes"
  type = object({
    persistent_volumes = map(object({
      size        = string
      type        = string
      mount_path  = string
      read_only   = bool
    }))
    ephemeral_storage = object({
      size      = string
      mount_path = string
    })
    shared_storage = object({
      enabled    = bool
      size       = string
      mount_path = string
    })
  })
  default = {
    persistent_volumes = {
      agent_cache = {
        size       = "10GB"
        type       = "gp3"
        mount_path = "/var/cache/agent"
        read_only  = false
      }
      git_repos = {
        size       = "20GB"
        type       = "gp3"
        mount_path = "/var/repos"
        read_only  = false
      }
    }
    ephemeral_storage = {
      size       = "5GB"
      mount_path = "/tmp/workspace"
    }
    shared_storage = {
      enabled    = true
      size       = "50GB"
      mount_path = "/var/shared"
    }
  }
}

variable "network_config" {
  description = "Network configuration for agent sandboxes"
  type = object({
    vpc_id              = string
    subnet_ids          = list(string)
    security_group_ids  = list(string)
    enable_nat_gateway  = bool
    dns_servers         = list(string)
    allowed_ports       = list(number)
    blocked_ports       = list(number)
  })
}

variable "monitoring_config" {
  description = "Monitoring and observability configuration"
  type = object({
    enable_metrics     = bool
    metrics_interval   = number
    enable_logging     = bool
    log_level          = string
    enable_tracing     = bool
    retention_days     = number
  })
  default = {
    enable_metrics   = true
    metrics_interval = 30
    enable_logging   = true
    log_level        = "INFO"
    enable_tracing   = true
    retention_days   = 30
  }
}

variable "cleanup_config" {
  description = "Cleanup and lifecycle management configuration"
  type = object({
    auto_cleanup_enabled = bool
    cleanup_interval     = number
    max_idle_time        = number
    max_lifetime         = number
    cleanup_on_failure   = bool
  })
  default = {
    auto_cleanup_enabled = true
    cleanup_interval     = 300
    max_idle_time        = 1800
    max_lifetime         = 86400
    cleanup_on_failure   = true
  }
}

variable "integration_config" {
  description = "Integration configuration with external services"
  type = object({
    github_app_id         = string
    github_installation_id = string
    github_private_key_secret_arn = string
    webhook_url           = string
    vault_integration     = bool
    consul_integration    = bool
  })
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}