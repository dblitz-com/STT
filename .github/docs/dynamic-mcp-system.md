# Dynamic MCP System for Claude Code Actions

This document describes how to use the Dynamic MCP (Model Context Protocol) system integrated with Claude Code Actions for context-aware tool provisioning.

## Overview

The Dynamic MCP system allows you to specify exactly which tools Claude needs for a specific task by using structured comments. Instead of Claude having access to all tools all the time, you can provision only the tools needed for the specific job, improving security, performance, and cost-effectiveness.

## Quick Start

### Basic Usage

```markdown
@claude use mcp:flux,monitoring check deployment status in staging
```

```markdown
@claude use mcp:testing,security run comprehensive security scan
```

```markdown
@claude use mcp:database,api-gen create CRUD endpoints for user table
```

### Using Presets

```markdown
@claude use preset:devops troubleshoot failing deployment
```

```markdown
@claude use preset:development implement new API feature
```

### With Environment Variables

```markdown
@claude env:TEST_ENV=staging use mcp:testing run integration tests
```

## Available MCP Servers

### Core Infrastructure

- **flux** - FluxCD GitOps operations
  - Tools: `flux_status`, `flux_logs`, `flux_reconcile`, `flux_get_sources`, etc.
  - Use for: GitOps troubleshooting, deployment monitoring

- **kubernetes** - Kubernetes cluster management
  - Tools: `kubectl_get`, `kubectl_describe`, `kubectl_logs`, `kubectl_apply`, etc.
  - Use for: Cluster operations, resource management

- **monitoring** - Prometheus & Grafana integration
  - Tools: `prometheus_query`, `grafana_create_dashboard`, `grafana_create_alert`, etc.
  - Use for: Metrics analysis, dashboard creation, alerting

### Development Tools

- **testing** - Test execution and quality assurance
  - Tools: `run_tests`, `run_coverage`, `run_linting`, `run_security_scan`, etc.
  - Use for: Running tests, code quality checks

- **security** - Security scanning and analysis
  - Tools: `security_scan_code`, `security_scan_dependencies`, `security_scan_container`, etc.
  - Use for: Vulnerability assessment, compliance checks

- **api-gen** - API generation and documentation
  - Tools: `generate_openapi_spec`, `generate_client_sdk`, `generate_api_docs`, etc.
  - Use for: API development, documentation generation

### Data & Integration

- **database** - Database operations
  - Tools: `db_query`, `db_execute`, `db_migrate`, `db_backup`, etc.
  - Use for: Database management, migrations

- **git** - Git operations
  - Tools: `git_status`, `git_diff`, `git_branch`, `git_create_pr`, etc.
  - Use for: Version control, branch management

- **docker** - Container operations
  - Tools: `docker_build`, `docker_push`, `docker_run`, `docker_compose_up`, etc.
  - Use for: Container management, image building

### AI & Code Generation

- **ai-code** - AI-powered code generation
  - Tools: `generate_code`, `analyze_code`, `optimize_code`, `explain_code`, etc.
  - Use for: Code generation, analysis, optimization

## Presets

Presets are predefined combinations of MCP servers for common workflows:

### DevOps (`preset:devops`)
- Servers: `flux`, `monitoring`, `kubernetes`, `security`, `docker`
- Use for: Deployment operations, monitoring, troubleshooting

### Development (`preset:development`)
- Servers: `git`, `testing`, `security`, `api-gen`, `ai-code`
- Use for: Feature development, testing, code review

### Data Operations (`preset:data`)
- Servers: `database`, `testing`, `security`, `monitoring`
- Use for: Database operations, data analysis

### Security (`preset:security`)
- Servers: `security`, `kubernetes`, `docker`, `monitoring`
- Use for: Security audits, vulnerability assessments

### GitOps (`preset:gitops`)
- Servers: `flux`, `kubernetes`, `git`, `monitoring`, `security`
- Use for: Complete GitOps workflow management

## Environment Variables

### Required Secrets

Set these in your GitHub repository secrets:

```yaml
# Core
ANTHROPIC_API_KEY: "your-anthropic-api-key"
GITHUB_TOKEN: "github-token-with-repo-permissions"

# Kubernetes & FluxCD
KUBECONFIG: "base64-encoded-kubeconfig"
PROMETHEUS_URL: "https://prometheus.your-cluster.com"
GRAFANA_URL: "https://grafana.your-cluster.com"
GRAFANA_TOKEN: "your-grafana-api-token"

# Database
DATABASE_URL: "postgresql://user:pass@host:5432/db"

# Docker Registry
DOCKER_REGISTRY: "your-registry.com"
DOCKER_REGISTRY_TOKEN: "registry-auth-token"
```

### Environment Variable Hints

You can specify environment variables in comments:

```markdown
@claude env:SECURITY_SCAN_LEVEL=high,TEST_ENV=staging use mcp:security,testing audit application security
```

## Advanced Usage

### Custom Server Dependencies

Some servers have dependencies that are automatically resolved:

- `flux` depends on `kubernetes`
- When you specify `flux`, `kubernetes` is automatically included

### Security Policies

The system supports different security policies:

- **default** - Standard tool access
- **restricted** - Limited tool access
- **elevated** - Full tool access (requires approval)

### Configuration Templates

Based on the number of servers, different resource templates are used:

- **minimal** (≤2 servers) - 512Mi memory, 500m CPU
- **standard** (≤5 servers) - 1Gi memory, 1000m CPU
- **comprehensive** (>5 servers) - 2Gi memory, 2000m CPU

## Examples

### FluxCD Troubleshooting

```markdown
@claude use mcp:flux,monitoring 

The staging deployment is failing. Can you:
1. Check the flux status
2. Look at the gitrepository and kustomization resources
3. Check prometheus metrics for any errors
4. Provide troubleshooting steps
```

### Comprehensive Testing

```markdown
@claude use mcp:testing,security,database env:TEST_ENV=staging

Run comprehensive tests for the user management API:
1. Run unit tests with coverage
2. Run integration tests against staging database
3. Perform security scan
4. Generate test report
```

### API Development

```markdown
@claude use preset:development

Create a new REST API for product management:
1. Generate OpenAPI specification
2. Create CRUD endpoints
3. Add input validation
4. Write comprehensive tests
5. Update documentation
```

### Database Migration

```markdown
@claude use mcp:database,testing env:DATABASE_URL=staging

Create a migration to add user preferences table:
1. Create migration file
2. Test migration on staging
3. Create rollback script
4. Update API models
```

### Security Audit

```markdown
@claude use preset:security env:SECURITY_SCAN_LEVEL=high

Perform comprehensive security audit:
1. Scan codebase for vulnerabilities
2. Check container images
3. Audit Kubernetes configurations
4. Review network policies
5. Generate security report
```

## System Architecture

### Components

1. **MCP Registry** (`.github/mcp-registry.json`) - Defines available servers
2. **Comment Parser** (`.github/scripts/mcp-comment-parser.js`) - Extracts requirements
3. **Config Builder** (`.github/scripts/mcp-config-builder.js`) - Generates configurations
4. **GitHub Actions** (`.github/workflows/claude-code.yml`) - Orchestrates execution

### Flow

1. User writes comment with MCP directive
2. GitHub Actions triggers on comment
3. Comment parser extracts MCP requirements
4. Config builder generates dynamic MCP configuration
5. Claude Code Actions runs with specific tools
6. Results are posted back to GitHub

## Troubleshooting

### Common Issues

#### Invalid Server Names
```
Error: Invalid MCP configuration: {"invalid_servers": ["invalid-server"]}
```
**Solution:** Check available servers in the registry or use a preset.

#### Missing Environment Variables
```
Error: Required environment variable KUBECONFIG not found
```
**Solution:** Add the required secret to your GitHub repository.

#### Server Conflicts
```
Error: server1 conflicts with server2
```
**Solution:** Check the registry for server conflicts and choose compatible servers.

### Debug Information

Each execution generates artifacts containing:
- Parsed comment requirements
- Generated MCP configuration
- Execution logs

Access these through the GitHub Actions artifacts.

## Development

### Adding New MCP Servers

1. Add server definition to `.github/mcp-registry.json`
2. Implement the actual MCP server (external project)
3. Update documentation
4. Test with the comment parser system

### Modifying Presets

Edit the `presets` section in `.github/mcp-registry.json` to add new combinations or modify existing ones.

## Security Considerations

- MCP servers run in isolated containers
- Only specified tools are available to Claude
- Environment variables are managed through GitHub secrets
- All actions are logged and auditable
- Minimal tool provisioning reduces attack surface

## Contributing

1. Test changes with the comment parser: `node .github/scripts/mcp-comment-parser.js`
2. Validate configuration generation: `node .github/scripts/mcp-config-builder.js`
3. Update documentation for new features
4. Test in a fork before submitting PR

## License

This dynamic MCP system is part of the gengine project and follows the same license terms.