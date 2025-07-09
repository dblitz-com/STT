# Agent Permissions Module

A Terragrunt module for managing IAM roles, policies, and permissions for AI coding agents. This module implements **least-privilege security** with comprehensive permission management, monitoring, and cross-account access capabilities.

## Architecture

This module creates a layered permission system:

```
┌─────────────────────────────────────────────────────────────┐
│                   Agent Permissions                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Base Role     │    │GitHub App   │    │   Vault     │  │
│  │  (All Agents)   │◄──►│Integration  │◄──►│Integration  │  │
│  └─────────────────┘    └─────────────┘    └─────────────┘  │
│           │                     │                   │       │
│           ▼                     ▼                   ▼       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Agent Type Specific Roles               │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │ │
│  │  │ Coder   │ │ Tester  │ │Reviewer │ │  Docs   │      │ │
│  │  │ Role    │ │ Role    │ │ Role    │ │ Role    │      │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘      │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    Security & Monitoring                   │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│ │ CloudTrail  │ │ CloudWatch  │ │ Access Logs │            │
│ │ Auditing    │ │ Alarms      │ │ Monitoring  │            │
│ └─────────────┘ └─────────────┘ └─────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

- **Least-Privilege Access**: Each agent type has minimal required permissions
- **Role Hierarchy**: Base role with type-specific extensions
- **GitHub App Integration**: Secure repository access with GitHub Apps
- **Vault Integration**: HashiCorp Vault support for secret management
- **Cross-Account Access**: Multi-environment deployment support
- **Security Monitoring**: CloudTrail auditing and CloudWatch alarms
- **Resource Restrictions**: Granular S3, Secrets Manager, and GitHub access controls
- **IP Restrictions**: Network-based access controls

## Agent Permission Matrix

| Agent Type | GitHub Permissions | AWS Services | Vault Policies | Special Access |
|------------|-------------------|--------------|----------------|----------------|
| **Coder** | contents:read/write, pull_requests:write | S3, Logs, Secrets Manager | coder-secrets | Repository write access |
| **Tester** | contents:read, checks:write | Logs, Secrets Manager | test-secrets | Test result storage |
| **Reviewer** | contents:read, pull_requests:read/write | Logs, Secrets Manager | base only | Review permissions |
| **Docs** | contents:read/write, pull_requests:write | Logs, Secrets Manager | base only | Documentation access |

## Usage

### Basic Configuration

```hcl
# agent-permissions/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/agent-permissions"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  cluster_name = "gengine-dev"
  environment  = "development"
  
  github_app_config = {
    app_id                 = "1529272"
    installation_id        = "74523281"
    private_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789:secret:github-app-key"
    webhook_secret_arn     = "arn:aws:secretsmanager:us-west-2:123456789:secret:webhook-secret"
    permissions = {
      contents       = "write"
      pull_requests  = "write" 
      issues         = "read"
      metadata       = "read"
    }
  }
  
  aws_config = {
    region               = "us-west-2"
    account_id           = data.aws_caller_identity.current.account_id
    vpc_id               = dependency.vpc.outputs.vpc_id
    subnet_ids           = dependency.vpc.outputs.private_subnet_ids
    s3_bucket_name       = "gengine-dev-agent-storage"
    cloudwatch_log_group = "/agent-sandbox/gengine-dev"
    secrets_kms_key_arn  = "arn:aws:kms:us-west-2:123456789:key/12345678-1234-1234-1234-123456789012"
  }
  
  nomad_config = {
    nomad_endpoint   = "https://nomad.dev.gengine.com"
    nomad_region     = "global"
    nomad_datacenter = "dc1"
    acl_enabled      = true
    tls_enabled      = true
    ca_cert_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789:secret:nomad-ca-cert"
  }
}
```

### Advanced Configuration with Vault

```hcl
inputs = {
  # Base configuration...
  
  vault_config = {
    vault_endpoint       = "https://vault.dev.gengine.com"
    vault_namespace      = "gengine"
    auth_method         = "aws"
    role_id_secret_arn   = "arn:aws:secretsmanager:us-west-2:123456789:secret:vault-role-id"
    secret_id_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789:secret:vault-secret-id"
    enable_transit      = true
    transit_mount_path  = "transit"
  }
  
  # Custom agent type permissions
  agent_types = {
    senior_coder = {
      github_permissions = [
        "contents:write",
        "pull_requests:write",
        "actions:write",
        "deployments:write"
      ]
      aws_permissions = [
        "logs:*",
        "secretsmanager:GetSecretValue",
        "s3:*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability"
      ]
      vault_policies = ["agent-base", "github-integration", "senior-coder-secrets", "deployment-secrets"]
      resource_access = ["repositories", "pull_requests", "artifacts", "deployments"]
      cross_account_access = true
    }
  }
}
```

### Security Configuration

```hcl
inputs = {
  # Enhanced security policies
  security_policies = {
    enforce_mfa              = true
    require_request_signing  = true
    ip_restriction_enabled   = true
    allowed_ip_cidrs         = ["10.0.0.0/8", "172.16.0.0/12"]
    session_duration_seconds = 3600
    external_id_required     = true
    condition_keys = {
      "StringEquals" = {
        "aws:RequestedRegion" = ["us-west-2", "us-east-1"]
      }
    }
  }
  
  # Resource restrictions
  resource_restrictions = {
    s3_bucket_restrictions = {
      coder = {
        allowed_prefixes = ["coder/*", "shared/code/*"]
        denied_prefixes  = ["admin/*", "secrets/*"]
        max_object_size  = 104857600  # 100MB
      }
      tester = {
        allowed_prefixes = ["tester/*", "shared/tests/*"]
        denied_prefixes  = ["admin/*", "production/*"]
        max_object_size  = 52428800   # 50MB
      }
    }
    
    secrets_restrictions = {
      allowed_secret_patterns = ["github-app/*", "agent-config/*", "test-data/*"]
      denied_secret_patterns  = ["admin/*", "root/*", "production/*"]
    }
    
    github_restrictions = {
      allowed_repositories = ["dblitz-com/gengine", "dblitz-com/docs"]
      denied_repositories  = ["dblitz-com/admin", "dblitz-com/secrets"]
      max_file_size       = 10485760  # 10MB
      allowed_file_types  = [".py", ".js", ".ts", ".md", ".json", ".yaml", ".yml", ".txt"]
    }
  }
}
```

### Cross-Account Setup

```hcl
inputs = {
  # Cross-account configuration for multi-environment deployments
  cross_account_config = {
    enabled            = true
    target_account_ids = ["123456789012", "210987654321"]  # staging, production
    target_roles = {
      staging_deployer = "arn:aws:iam::123456789012:role/gengine-staging-deployer"
      prod_deployer    = "arn:aws:iam::210987654321:role/gengine-prod-deployer"
    }
    assume_role_conditions = {
      staging_deployer = {
        "StringEquals" = {
          "aws:PrincipalTag/Environment" = ["staging"]
        }
      }
      prod_deployer = {
        "StringEquals" = {
          "aws:PrincipalTag/Environment" = ["production"]
        }
        "DateGreaterThan" = {
          "aws:CurrentTime" = "2024-01-01T00:00:00Z"
        }
      }
    }
  }
}
```

## Monitoring and Auditing

### CloudTrail Integration

The module automatically sets up CloudTrail for auditing all IAM operations:

```hcl
inputs = {
  monitoring_config = {
    enable_cloudtrail     = true
    enable_access_logging = true
    log_retention_days    = 90
    enable_alerts         = true
    alert_sns_topic_arn   = "arn:aws:sns:us-west-2:123456789:security-alerts"
  }
}
```

### Security Monitoring

Built-in CloudWatch alarms monitor for:
- Unauthorized access attempts
- Permission escalation attempts
- Unusual API usage patterns
- Cross-account access anomalies

### Viewing Audit Logs

```bash
# View agent permission usage
aws logs filter-log-events \
  --log-group-name "/agent-permissions/gengine-dev" \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000

# Check CloudTrail for role assumptions
aws logs filter-log-events \
  --log-group-name "aws-cloudtrail-logs-123456789-gengine" \
  --filter-pattern "AssumeRole" \
  --start-time $(date -d '1 hour ago' +%s)000
```

## Integration with Other Modules

### Agent Orchestrator Integration

```hcl
# In agent-orchestrator module
dependency "permissions" {
  config_path = "../agent-permissions"
}

inputs = {
  agent_role_arn = dependency.permissions.outputs.agent_base_role_arn
  
  agent_types = {
    coder = {
      # ... other config
      execution_role_arn = dependency.permissions.outputs.agent_type_role_arns["coder"]
    }
  }
}
```

### Sandbox Integration

```hcl
# In agent-sandbox module  
dependency "permissions" {
  config_path = "../agent-permissions"
}

inputs = {
  execution_role_arn = dependency.permissions.outputs.agent_base_role_arn
  
  integration_config = {
    github_private_key_secret_arn = dependency.permissions.outputs.github_app_configuration.private_key_secret_arn
  }
}
```

## Security Best Practices

### 1. Principle of Least Privilege
- Each agent type has minimal required permissions
- Resource-specific access controls (S3 prefixes, secret patterns)
- Time-bounded sessions with automatic expiration

### 2. Defense in Depth
- Multiple layers of access controls
- Network restrictions (IP allowlists)
- Resource-level restrictions
- Audit logging and monitoring

### 3. Secret Management
- GitHub App private keys stored in AWS Secrets Manager
- KMS encryption for all secrets
- Vault integration for additional secret management
- No hardcoded credentials in configuration

### 4. Monitoring and Alerting
- CloudTrail auditing for all permission changes
- CloudWatch alarms for security events
- Access logging for forensic analysis
- SNS notifications for critical security events

## Outputs

The module provides comprehensive outputs for integration:

```hcl
# Access agent role ARNs
agent_role_arn = module.agent_permissions.agent_type_role_arns["coder"]

# GitHub App configuration
github_config = module.agent_permissions.github_app_configuration

# Security monitoring
cloudtrail_arn = module.agent_permissions.cloudtrail_arn
access_logs    = module.agent_permissions.access_log_group_name

# Cross-account roles (if enabled)
cross_account_roles = module.agent_permissions.cross_account_role_arns
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**: Check IAM policy attachments and resource restrictions
2. **Cross-Account Access Failing**: Verify external ID and assume role conditions
3. **GitHub Integration Issues**: Validate GitHub App configuration and secret access
4. **Vault Integration Problems**: Check Vault policies and AWS auth configuration

### Debugging Commands

```bash
# Check agent role permissions
aws iam list-attached-role-policies --role-name gengine-dev-coder-agent-role

# Test role assumption
aws sts assume-role \
  --role-arn "arn:aws:iam::123456789:role/gengine-dev-coder-agent-role" \
  --role-session-name "test-session"

# Validate GitHub App secret access
aws secretsmanager get-secret-value \
  --secret-id "arn:aws:secretsmanager:us-west-2:123456789:secret:github-app-key"

# Check security alarms
aws cloudwatch describe-alarms \
  --alarm-names "gengine-dev-unauthorized-access"
```

## Contributing

When extending this module:

1. **Follow Security Principles**: Always apply least-privilege access
2. **Update Documentation**: Document new permissions and their purpose
3. **Add Monitoring**: Include appropriate logging and alerting
4. **Test Cross-Account**: Verify multi-environment scenarios
5. **Review Policies**: Have security team review new IAM policies