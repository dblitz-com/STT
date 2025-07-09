# FluxCD GitOps with Claude Code Actions

This guide shows how to use Claude Code Actions with the official Flux Operator MCP Server for AI-assisted GitOps operations.

## Overview

The GitHub Actions workflow (`.github/workflows/claude-code.yml`) automatically installs and configures the Flux Operator MCP Server, giving Claude direct access to your Kubernetes cluster and FluxCD resources.

## Usage

Simply comment on any GitHub issue or PR with natural language requests:

### Basic FluxCD Operations

```markdown
@claude analyze the Flux installation and report status of all components
```

```markdown
@claude perform root cause analysis of failed deployment in staging
```

```markdown
@claude resume all suspended Flux resources and verify status
```

### GitOps Pipeline Analysis

```markdown
@claude list all Flux Kustomizations and show dependency diagram
```

```markdown
@claude check GitRepository sources for sync issues
```

```markdown
@claude get logs from flux controllers for troubleshooting
```

### Submodule-Specific Operations

```markdown
@claude check the status of gengine-mcp-catalog deployment in staging
```

```markdown
@claude troubleshoot gengine-rest-api-to-mcp production deployment
```

```markdown
@claude compare staging and production configurations for gengine-mcp-catalog
```

## Available Tools

The Flux Operator MCP Server provides these tools:

- **flux_get_all** - Get all Flux resources
- **flux_get_sources** - Get GitRepository, HelmRepository, and Bucket sources
- **flux_get_kustomizations** - Get Kustomization resources
- **flux_get_helmreleases** - Get HelmRelease resources
- **flux_logs** - Get logs from Flux controllers
- **flux_reconcile** - Force reconciliation of resources
- **flux_suspend** - Suspend resource reconciliation
- **flux_resume** - Resume resource reconciliation
- **flux_delete** - Delete Flux resources
- **flux_export** - Export Flux resources
- **flux_diff** - Show diff for Kustomizations
- **flux_tree** - Show resource tree
- **kubectl_get** - Get Kubernetes resources
- **kubectl_describe** - Describe Kubernetes resources
- **kubectl_logs** - Get pod logs
- **kubectl_events** - Get cluster events

## Gengine Project Context

The Claude assistant understands the gengine project structure:

- **Submodules**: Located in `src/gengines/` directory
- **Dynamic Provisioning**: FluxCD auto-discovers and provisions GitOps pipelines every 2 minutes
- **Environments**: 
  - Staging (dev branch) → gengine-staging namespace
  - Production (main branch) → gengine-production namespace
- **Testing**: Comprehensive testing runs for each submodule before deployment

### Key Resources

- **gengine-mcp-catalog-dev/main** - GitRepository for MCP catalog
- **gengine-rest-api-to-mcp-dev/main** - GitRepository for REST API to MCP
- **Associated Kustomizations** - For staging/production environments
- **Test Jobs** - In gengine-staging/gengine-production namespaces

## Required GitHub Secrets

Set these secrets in your repository:

- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `KUBECONFIG` - Base64-encoded kubeconfig file
- `PROMETHEUS_URL` - Prometheus endpoint (optional)
- `GRAFANA_URL` - Grafana endpoint (optional)
- `GRAFANA_TOKEN` - Grafana API token (optional)

## Examples

### Troubleshooting Deployment Issues

```markdown
@claude The staging deployment is failing. Can you:
1. Check the flux status
2. Look at the gitrepository and kustomization resources
3. Check for any errors in the logs
4. Provide troubleshooting steps
```

### Monitoring Submodule Health

```markdown
@claude Check the health of all gengine submodules:
1. Verify GitRepository sources are syncing
2. Check Kustomization reconciliation status
3. Look at test job results
4. Report any issues found
```

### GitOps Pipeline Visualization

```markdown
@claude Create a visualization of the GitOps pipeline showing:
1. All GitRepository sources
2. Kustomization dependencies
3. Target namespaces
4. Current sync status
```

## Workflow Details

When you comment, the workflow:

1. **Installs** the Flux Operator MCP Server
2. **Configures** kubeconfig from GitHub secrets
3. **Launches** Claude Code Actions with MCP access
4. **Provides** project context and instructions
5. **Summarizes** execution results

## Security

- Uses your existing kubeconfig permissions
- Runs in isolated GitHub Actions environment
- All operations are logged and auditable
- Secrets are managed through GitHub secrets

## Troubleshooting

If Claude can't access the cluster:

1. Verify `KUBECONFIG` secret is base64-encoded
2. Check cluster connectivity
3. Ensure kubeconfig has sufficient permissions
4. Review GitHub Actions logs for errors

## Official Documentation

For more details on the Flux Operator MCP Server:
- [Installation Guide](https://flux-operator.controlplane.io/mcp/installation/)
- [Configuration Options](https://flux-operator.controlplane.io/mcp/configuration/)
- [API Reference](https://flux-operator.controlplane.io/mcp/api-reference/)