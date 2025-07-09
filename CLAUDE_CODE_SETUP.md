# Claude Code Setup Summary

## ✅ What We've Completed

1. **Integrated Official Claude Code Actions**
   - Cloned claude-code-action to `src/coding/claudecode/claudecodeaction/`
   - Cloned claude-code-base-action to `src/coding/claudecode/claudecodebaseaction/`
   - Created shared kubernetes-core utility in `src/coding/utils/`
   - Fixed all import paths and tests

2. **Created Kubernetes Entry Points**
   - `src/coding/entrypoints/claude-runner.ts` - Main runner for Kubernetes Jobs
   - `src/coding/entrypoints/webhook-claude-handler.ts` - Webhook handler that creates Jobs

3. **Updated Infrastructure**
   - Modified webhook-server to use new handler
   - Archived old Claude implementations to `src/coding/archive/claude-old/`

## 🔄 Automated Pipeline Flow

```
GitHub Push → Tekton → ECR → FluxCD → Kubernetes
     ↓
GitHub Webhook → Webhook Server → Create Job → Run Claude
```

## 📋 Setup Checklist

### 1. Push Code (Automatic Build/Deploy)
```bash
git add -A
git commit -m "feat: Integrate official Claude Code actions with Kubernetes"
git push origin feature/clean-mcp-restructure
```

The pipeline will automatically:
- Build Docker images via Tekton
- Push to ECR with timestamp tags
- FluxCD will detect and deploy new images

### 2. Create Kubernetes Secrets (One-time)
```bash
# Check if secrets already exist
kubectl get secrets -n default | grep -E "claude-secrets|github-token-secret|example-app-secrets"

# If not, create them:
kubectl create secret generic claude-secrets \
  --from-literal=anthropic-api-key=YOUR_ANTHROPIC_API_KEY \
  --from-literal=github-token=YOUR_GITHUB_TOKEN \
  -n default

kubectl create secret generic github-token-secret \
  --from-literal=token=YOUR_GITHUB_TOKEN \
  -n default

# Generate webhook secret if needed
WEBHOOK_SECRET=$(openssl rand -hex 32)
kubectl create secret generic example-app-secrets \
  --from-literal=webhook-secret=$WEBHOOK_SECRET \
  -n default
```

### 3. Configure GitHub Webhook

**Option A: Automated Setup**
```bash
export GITHUB_TOKEN=ghp_your_token_with_repo_hook_permissions
./configure-webhook-api.sh
```

**Option B: Manual Setup**
```bash
./setup-github-webhook.sh
# Follow the printed instructions
```

### 4. Test the Integration
1. Create an issue or PR in the repository
2. Comment with: `@claude help me understand this code`
3. Claude should respond and start working!

## 🔍 Monitoring

```bash
# Watch webhook server logs
kubectl logs -f deployment/webhook-server -n default

# Watch for Claude jobs
kubectl get jobs -n default -w

# Check specific job logs
kubectl logs job/claude-job-xxxxx -n default
```

## 🚨 Troubleshooting

1. **Webhook not triggering**
   - Check webhook deliveries at GitHub settings
   - Verify webhook secret matches
   - Check webhook server is accessible

2. **Jobs not starting**
   - Check secrets exist: `kubectl get secrets -n default`
   - Check RBAC permissions for webhook-server ServiceAccount
   - Look for ConfigMap creation errors

3. **Claude not responding**
   - Check Anthropic API key is valid
   - Check GitHub token has required permissions
   - Review job logs for errors

## 📂 Key Files

- Entry points: `src/coding/entrypoints/`
- Claude actions: `src/coding/claudecode/`
- Infrastructure: `infrastructure/apps/base/`
- Dockerfiles: `Dockerfile.claude-runner`, `src/webhook-server/Dockerfile`