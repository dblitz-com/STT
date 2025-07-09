# Flux GitHub Webhook Setup

## Current Configuration

Flux Receiver is configured and running with the following components:

- **Receiver Name**: `github-webhook-receiver`
- **Webhook Path**: `/hook/1f7be6e93d91e72e95bb1c4d95bc3d00e9d626c0e20a8f8607892eb3fff47db2`
- **Local Port Forward**: `kubectl port-forward -n flux-system svc/webhook-receiver 9001:80`
- **Local Webhook URL**: `http://localhost:9001/hook/1f7be6e93d91e72e95bb1c4d95bc3d00e9d626c0e20a8f8607892eb3fff47db2`

## Setup Steps

### 1. Expose Webhook Externally

For GitHub to reach the webhook, expose it using ngrok:

```bash
# Install ngrok (if not already installed)
brew install ngrok

# Expose the local webhook receiver
ngrok http 9001
```

This will provide a public URL like: `https://abc123.ngrok.io`

### 2. Configure GitHub Webhook

1. Go to your GitHub repository: `https://github.com/dblitz-com/gengine`
2. Navigate to **Settings** > **Webhooks**
3. Click **Add webhook**
4. Configure:
   - **Payload URL**: `https://your-ngrok-url.ngrok.io/hook/1f7be6e93d91e72e95bb1c4d95bc3d00e9d626c0e20a8f8607892eb3fff47db2`
   - **Content type**: `application/json`
   - **Secret**: `flux-webhook-secret-change-me` (from the secret in flux-system)
   - **Events**: Select "Push" events for the `feature/clean-mcp-restructure` branch

### 3. Test Webhook

Make a commit to the `feature/clean-mcp-restructure` branch to trigger the webhook:

```bash
git add .
git commit -m "test: trigger flux webhook"
git push origin feature/clean-mcp-restructure
```

### 4. Monitor Webhook Activity

```bash
# Check receiver logs
kubectl logs -n flux-system -l app=notification-controller -f

# Check Git repository sync status
flux get sources git

# Check kustomization status
flux get kustomizations
```

## Production Setup

For production, replace ngrok with:

1. **Ingress Controller** (nginx, traefik) with proper domain
2. **Load Balancer** service type
3. **TLS certificates** for HTTPS
4. **Proper webhook secret** (generate secure random string)

## Webhook Events Handled

The current configuration triggers on:
- Git repository changes (push events)
- Flux reconciliation events
- Kustomization updates

## Troubleshooting

```bash
# Check receiver status
kubectl get receivers -n flux-system

# Check provider status  
kubectl get providers -n flux-system

# Check alerts
kubectl get alerts -n flux-system

# View notification controller logs
kubectl logs -n flux-system deploy/notification-controller
```