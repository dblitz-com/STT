# GitHub Actions Self-Hosted Runners on Kubernetes

This directory contains the infrastructure to deploy GitHub Actions self-hosted runners in Kubernetes using [actions-runner-controller (ARC)](https://github.com/actions/actions-runner-controller).

## Overview

**This is Option A - the PREFERRED solution** for running Claude Code Actions. It provides:

- ✅ Proper GitHub Actions context and environment variables
- ✅ Correct status comment formatting that matches official GitHub Actions
- ✅ Auto-scaling based on workflow queue
- ✅ Better integration with GitHub ecosystem  
- ✅ Official support and maintenance

## Prerequisites

1. **Kubernetes cluster** with admin access
2. **kubectl** configured to access the cluster
3. **GitHub Personal Access Token (PAT)** with required permissions:
   - `repo` (for private repositories)
   - `admin:org` (for organization-level runners)  
   - `admin:public_key` (for SSH key management)
   - `admin:repo_hook` (for webhook management)

## Quick Start

### 1. Set up GitHub Token

Create a GitHub Personal Access Token and encode it in base64:

```bash
# Replace YOUR_GITHUB_TOKEN with your actual token
echo -n "YOUR_GITHUB_TOKEN" | base64
```

Update the token in `actions-runner-controller.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: controller-manager
  namespace: actions-runner-system
data:
  github_token: "YOUR_BASE64_ENCODED_TOKEN_HERE"
```

### 2. Configure Repository

Update the repository in `runner-deployment.yaml`:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: claude-code-runners
spec:
  template:
    spec:
      repository: YOUR_ORG/YOUR_REPO  # Update this
```

### 3. Deploy Infrastructure

```bash
# Deploy everything using kustomize
kubectl apply -k .

# Or deploy manually in order:
kubectl apply -f cert-manager.yaml
kubectl apply -f arc-crds.yaml  
kubectl apply -f actions-runner-controller.yaml
kubectl apply -f runner-deployment.yaml
```

### 4. Verify Installation

```bash
# Check if cert-manager is ready
kubectl get pods -n cert-manager

# Check if ARC controller is running
kubectl get pods -n actions-runner-system

# Check if runners are registered
kubectl get runners -n actions-runner-system
kubectl get runnerdeployments -n actions-runner-system
```

### 5. Test GitHub Actions

Create a simple workflow in your repository:

```yaml
# .github/workflows/test-runners.yml
name: Test Self-Hosted Runners

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: [self-hosted, linux, x64, claude-code]
    steps:
    - uses: actions/checkout@v4
    - name: Test Runner
      run: |
        echo "Running on self-hosted runner!"
        echo "Node: $(hostname)"
        echo "OS: $(uname -a)"
```

## Components

### cert-manager.yaml
Installs cert-manager which is required for ARC's webhook TLS certificates.

### arc-crds.yaml  
Custom Resource Definitions for ARC resources (Runner, RunnerDeployment, etc.)

### actions-runner-controller.yaml
The main ARC controller that manages GitHub Actions runners in Kubernetes.

### runner-deployment.yaml
- **RunnerDeployment**: Defines the runner configuration and replicas
- **HorizontalRunnerAutoscaler**: Auto-scales runners based on workflow queue
- **ServiceMonitor**: Prometheus metrics collection (optional)

### kustomization.yaml
Kustomize configuration to deploy all resources with proper ordering and configuration.

## Auto-Scaling

The HorizontalRunnerAutoscaler automatically adjusts runner count based on:

- **Queue-based scaling**: Monitors GitHub Actions workflow queue
- **Utilization-based scaling**: Scales based on runner busy percentage
- **Webhook-based scaling**: Instant scaling on workflow events

Configuration:
- **Min replicas**: 1 (always keep one runner ready)
- **Max replicas**: 10 (scale up to 10 during high load)
- **Scale up threshold**: 75% busy or 2+ queued workflows
- **Scale down threshold**: 25% busy or 0 queued workflows

## Resource Requirements

Each runner requests:
- **Memory**: 4Gi (request) / 8Gi (limit)
- **CPU**: 2 cores (request) / 4 cores (limit) 
- **Storage**: 10Gi (request) / 20Gi (limit)

These resources are sized for Claude Code workloads which can be memory and CPU intensive.

## Security

- Runners use **ephemeral mode** (recommended by GitHub)
- **Docker-in-Docker** enabled for actions requiring containers
- **Non-root execution** with proper security contexts
- **Network policies** can be applied for additional isolation

## Monitoring

The setup includes Prometheus metrics via ServiceMonitor:
- Runner count and status
- Queue length and processing time
- Resource utilization
- Scaling events

## Troubleshooting

### Runners not appearing in GitHub

1. Check the GitHub token permissions
2. Verify repository name in RunnerDeployment  
3. Check ARC controller logs:
   ```bash
   kubectl logs -n actions-runner-system deployment/controller-manager
   ```

### Scaling not working

1. Check HorizontalRunnerAutoscaler status:
   ```bash
   kubectl describe hra claude-code-runners-autoscaler -n actions-runner-system
   ```

2. Verify webhook configuration in repository settings

### Resource issues

1. Check node resources:
   ```bash
   kubectl top nodes
   kubectl describe nodes
   ```

2. Adjust resource requests/limits in runner-deployment.yaml

## Migration from Custom Implementation

If migrating from the custom Kubernetes implementation (Option B):

1. **Deploy this infrastructure** following the steps above
2. **Update webhook handler** to trigger GitHub Actions workflows instead of Kubernetes Jobs
3. **Test workflows** with proper status comments
4. **Archive custom implementation** once verified working

The webhook handler should be updated to:
- Call GitHub API to trigger workflow_dispatch events
- Remove Kubernetes Job creation logic
- Let GitHub Actions handle the execution

## Next Steps

1. **Configure repository webhooks** to point to GitHub Actions instead of custom webhook
2. **Set up workflow_dispatch triggers** for Claude Code Actions  
3. **Test end-to-end flow** with issue comments and PRs
4. **Monitor scaling and performance** in production