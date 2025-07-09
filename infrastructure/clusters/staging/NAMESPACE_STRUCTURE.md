# Kubernetes Namespace Structure

## Overview

The GitOps setup includes a multi-environment namespace structure with proper isolation and organization.

## Created Namespaces

| Namespace | Purpose | Environment | Labels |
|-----------|---------|-------------|---------|
| `dev` | Development workloads | Development | `environment=dev`, `managed-by=flux` |
| `staging` | Staging/testing workloads | Staging | `environment=staging`, `managed-by=flux` |
| `prod` | Production workloads | Production | `environment=prod`, `managed-by=flux` |
| `system` | System/infrastructure services | System | `environment=system`, `managed-by=flux` |
| `flux-system` | Flux GitOps controllers | System | (Flux managed) |

## Directory Structure

```
infrastructure/
├── apps/
│   ├── base/                          # Common application manifests
│   │   ├── kustomization.yaml         # Base kustomization
│   │   ├── webhook-server-deployment.yaml
│   │   └── claude-runner-deployment.yaml
│   └── overlays/                      # Environment-specific configurations
│       ├── dev/
│       │   ├── kustomization.yaml     # Dev-specific overrides
│       │   └── dev-patches.yaml       # Dev environment patches
│       ├── staging/
│       │   ├── kustomization.yaml     # Staging-specific overrides
│       │   └── staging-patches.yaml   # Staging environment patches
│       └── prod/
│           ├── kustomization.yaml     # Prod-specific overrides
│           └── prod-patches.yaml      # Production environment patches
└── clusters/
    └── staging/
        ├── flux-system/               # Flux system configuration
        ├── namespaces.yaml           # Namespace definitions
        └── git-sources.yaml          # Git repository sources
```

## Network Policies

Each environment namespace has network policies that:
- **Deny cross-namespace traffic** by default
- **Allow communication within the same namespace**
- **Allow communication with `flux-system` namespace**
- **Allow DNS resolution** (UDP port 53)

### Example Policy Rules

```yaml
# Only allow traffic from same environment and flux-system
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: dev  # or staging, prod
  - namespaceSelector:
      matchLabels:
        name: flux-system
```

## Kustomization Configuration

### Base Configuration

- Shared resources across all environments
- Common labels and annotations
- Base deployment configurations

### Environment Overlays

| Environment | Image Tags | Replicas | Configuration |
|-------------|------------|----------|---------------|
| **Dev** | `dev-latest` | 1 | Development settings, verbose logging |
| **Staging** | `staging-latest` | 1-2 | Production-like settings, testing |
| **Prod** | `v1.0.0` (pinned) | 2-3 | Production settings, minimal logging |

## Usage Examples

### Deploy to Development

```bash
# Flux will automatically sync from git-sources
# Applications deployed to 'dev' namespace
kubectl get pods -n dev
```

### Deploy to Staging

```bash
# Staging deployments in 'staging' namespace
kubectl get pods -n staging
```

### Deploy to Production

```bash
# Production deployments in 'prod' namespace
kubectl get pods -n prod
```

## Environment-Specific Configurations

### Development (`dev`)
- Latest development images
- Debug mode enabled
- Lower resource limits
- Faster reconciliation intervals

### Staging (`staging`)
- Release candidate images
- Production-like configuration
- Medium resource allocation
- Standard reconciliation intervals

### Production (`prod`)
- Pinned stable image versions
- High availability (multiple replicas)
- Production resource allocation
- Conservative reconciliation intervals
- Enhanced monitoring and alerting

## Flux Integration

Each environment has corresponding Kustomization resources in Flux that:
- Monitor the appropriate git sources
- Apply changes to the correct namespace
- Handle environment-specific reconciliation

```bash
# Check environment-specific kustomizations
flux get kustomizations

# Monitor specific environment
flux logs --namespace=staging
```

## Security Considerations

1. **Namespace Isolation**: Network policies prevent cross-environment communication
2. **RBAC**: Each environment can have specific role-based access controls
3. **Resource Quotas**: Can be applied per namespace to limit resource usage
4. **Pod Security Standards**: Can be enforced per namespace

## Next Steps

1. Create environment-specific patches files
2. Add resource quotas per namespace
3. Configure environment-specific secrets
4. Set up monitoring per namespace
5. Implement RBAC for each environment