# Flagger Progressive Delivery Setup

## Overview

Flagger enables automated canary deployments, blue-green deployments, and A/B testing for Kubernetes applications. This setup integrates Flagger with Flux GitOps for automated progressive delivery.

## Components Installed

### 1. Flagger Controller
- **Purpose**: Manages canary deployments and traffic shifting
- **Namespace**: `flux-system`
- **Metrics Source**: Prometheus

### 2. Prometheus Stack
- **Purpose**: Provides metrics for canary analysis
- **Namespace**: `system`
- **Components**: Prometheus, Grafana, AlertManager

### 3. Canary Configurations
- **webhook-server**: Web application with HTTP metrics
- **claude-runner**: Background service with resource metrics

## Installation

```bash
# Apply Flagger and Prometheus setup
kubectl apply -f /Users/devin/dblitz/engine/infrastructure/clusters/staging/flagger-setup.yaml

# Verify Flagger installation
kubectl get pods -n flux-system | grep flagger

# Verify Prometheus installation
kubectl get pods -n system | grep prometheus
```

## Canary Deployment Strategies

### Development Environment
- **Rollout Speed**: Fast (30s intervals)
- **Canary Traffic**: Up to 100%
- **Step Size**: 50%
- **Success Threshold**: 80%
- **Purpose**: Rapid iteration and testing

### Staging Environment  
- **Rollout Speed**: Moderate (60s intervals)
- **Canary Traffic**: Up to 30%
- **Step Size**: 15%
- **Success Threshold**: 95%
- **Purpose**: Production-like validation

### Production Environment
- **Rollout Speed**: Conservative (120s intervals)
- **Canary Traffic**: Up to 20%
- **Step Size**: 5%
- **Success Threshold**: 99.5%
- **Purpose**: Maximum safety and reliability

## Monitored Metrics

### HTTP Services (webhook-server)
1. **Request Success Rate**: Percentage of successful HTTP requests
2. **Request Duration**: Average response time
3. **Error Rate**: Percentage of failed requests

### Background Services (claude-runner)
1. **CPU Usage**: Container CPU utilization
2. **Memory Usage**: Container memory utilization
3. **Request Success Rate**: Application-specific success metrics

## Canary Rollout Process

### 1. Automatic Trigger
- New image pushed to container registry
- Flux detects changes and updates deployment
- Flagger automatically starts canary analysis

### 2. Traffic Shifting
```
Phase 1: 0% → 5% → 10% → 15% → 20% (Production)
Phase 2: Monitor metrics at each step
Phase 3: Automatic rollback on failure
Phase 4: Promote to 100% on success
```

### 3. Analysis Steps
1. **Pre-rollout Tests**: Validation before traffic shift
2. **Canary Analysis**: Monitor metrics during rollout
3. **Confirmation**: Manual approval for production (optional)
4. **Promotion**: Complete rollout to new version

## Usage Examples

### Manual Canary Rollout
```bash
# Trigger a canary rollout by updating image
kubectl set image deployment/webhook-server \
  webhook-server=gengine-webhook-server:v2.0.0 \
  -n staging

# Monitor canary progress
kubectl get canary webhook-server -n staging -w

# Check canary events
kubectl describe canary webhook-server -n staging
```

### GitOps-Triggered Rollout
```bash
# Update kustomization with new image tag
# File: infrastructure/apps/overlays/staging/kustomization.yaml
images:
  - name: gengine-webhook-server
    newTag: v2.0.0

# Commit and push - Flux will automatically apply
git add . && git commit -m "feat: update webhook-server to v2.0.0"
git push origin feature/clean-mcp-restructure
```

## Monitoring and Observability

### Flagger Metrics Dashboard
```bash
# Access Grafana (if using port-forward)
kubectl port-forward -n system svc/prometheus-grafana 3000:80

# Default login: admin/admin123
# Import Flagger dashboard: https://grafana.com/grafana/dashboards/7726
```

### Command Line Monitoring
```bash
# List all canaries
kubectl get canaries -A

# Watch canary status
kubectl get canary webhook-server -n staging -w

# Check canary events
kubectl get events -n staging --field-selector involvedObject.kind=Canary

# Flagger logs
kubectl logs -n flux-system deploy/flagger -f
```

## Rollback Scenarios

### Automatic Rollback
Triggered when:
- Success rate drops below threshold
- Request duration exceeds limit
- Error rate increases above threshold
- Analysis webhooks fail

### Manual Rollback
```bash
# Reset canary (stops current rollout)
kubectl patch canary webhook-server -n staging \
  --type='merge' -p='{"spec":{"skipAnalysis":true}}'

# Revert to previous image
kubectl rollout undo deployment/webhook-server -n staging
```

## Advanced Configuration

### Custom Metrics
```yaml
metrics:
- name: custom-metric
  threshold: 90
  interval: 30s
  query: |
    rate(
      custom_requests_total{
        kubernetes_namespace="{{ namespace }}",
        kubernetes_pod_name=~"{{ target }}-[0-9a-zA-Z]+(-[0-9a-zA-Z]+)"
      }[1m]
    )
```

### Slack Notifications
```yaml
# Update flagger-setup.yaml
values:
  slack:
    url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
    channel: "#deployments"
    username: "Flagger"
```

### Load Testing Integration
```bash
# Install Flagger Load Tester
kubectl apply -k github.com/fluxcd/flagger//kustomize/tester

# Configure in canary
webhooks:
- name: load-test
  url: http://flagger-loadtester.test/
  metadata:
    cmd: "hey -z 1m -q 10 -c 2 http://webhook-server-canary/"
```

## Troubleshooting

### Common Issues

1. **Canary Stuck in Progressing**
   ```bash
   # Check metrics availability
   kubectl logs -n flux-system deploy/flagger | grep metrics
   
   # Verify Prometheus connectivity
   kubectl exec -n flux-system deploy/flagger -- wget -O- http://prometheus.system:9090/api/v1/query?query=up
   ```

2. **Metrics Not Available**
   ```bash
   # Check Prometheus targets
   kubectl port-forward -n system svc/prometheus-prometheus 9090:9090
   # Visit http://localhost:9090/targets
   ```

3. **Webhook Failures**
   ```bash
   # Check webhook endpoint
   kubectl describe canary webhook-server -n staging
   
   # Test webhook manually
   kubectl run debug --rm -it --image=curlimages/curl -- \
     curl -X POST http://flagger-loadtester.test/
   ```

### Performance Tuning

```yaml
# Faster rollouts for development
analysis:
  interval: 15s
  threshold: 1
  stepWeight: 25

# Conservative production settings
analysis:
  interval: 300s
  threshold: 20
  stepWeight: 2
```

## Security Considerations

1. **RBAC**: Flagger requires cluster-wide permissions
2. **Network Policies**: Configure to allow Flagger → Prometheus communication
3. **Webhook Security**: Secure webhook endpoints with authentication
4. **Metrics Security**: Protect Prometheus metrics endpoints

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Deploy to Staging
  run: |
    kubectl set image deployment/webhook-server \
      webhook-server=gengine-webhook-server:${{ github.sha }} \
      -n staging
    
    # Wait for canary completion
    kubectl wait --for=condition=Promoted \
      canary/webhook-server -n staging --timeout=600s
```

This Flagger setup provides comprehensive progressive delivery capabilities with environment-specific configurations and automated rollback on failure.