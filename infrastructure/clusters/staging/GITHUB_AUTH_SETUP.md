# GitHub Authentication Setup for Flux

## Overview

Flux requires authentication to access private GitHub repositories. This guide sets up SSH key authentication using GitHub deploy keys.

## Step 1: Generate SSH Key Pair

```bash
# Generate a new SSH key specifically for Flux
ssh-keygen -t ed25519 -C "flux@minikube-cluster" -f ~/.ssh/flux_deploy_key

# This creates:
# ~/.ssh/flux_deploy_key (private key)
# ~/.ssh/flux_deploy_key.pub (public key)
```

## Step 2: Add Deploy Key to GitHub

1. Copy the public key:
   ```bash
   cat ~/.ssh/flux_deploy_key.pub
   ```

2. Go to GitHub repository: `https://github.com/dblitz-com/gengine`
3. Navigate to **Settings** > **Deploy keys**
4. Click **Add deploy key**
5. Configure:
   - **Title**: `Flux GitOps Deploy Key`
   - **Key**: Paste the public key content
   - **Allow write access**: ✅ (checked)
6. Click **Add key**

## Step 3: Create Kubernetes Secret

Update the secret in `github-auth-setup.yaml` with your private key:

```bash
# Create the secret with your actual private key
kubectl create secret generic github-deploy-key \
  --namespace=flux-system \
  --from-file=identity=$HOME/.ssh/flux_deploy_key \
  --from-file=known_hosts=/dev/stdin <<EOF
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF
```

## Step 4: Apply Updated Configuration

```bash
# Apply the updated Git sources with SSH authentication
kubectl apply -f /Users/devin/dblitz/engine/infrastructure/clusters/staging/git-sources.yaml

# Apply the updated flux-system configuration
kubectl apply -k /Users/devin/dblitz/engine/infrastructure/clusters/staging/flux-system/
```

## Step 5: Verify Authentication

```bash
# Check Git source status
flux get sources git

# Check kustomization status
flux get kustomizations

# Watch for successful reconciliation
flux logs --all-namespaces --follow
```

## Alternative: Personal Access Token

If SSH keys don't work, use a GitHub Personal Access Token:

1. Generate PAT at: `https://github.com/settings/tokens`
2. Required scopes: `repo` (full repository access)
3. Create secret:
   ```bash
   kubectl create secret generic github-token \
     --namespace=flux-system \
     --from-literal=username=your-github-username \
     --from-literal=password=ghp_your_personal_access_token
   ```
4. Update GitRepository resources to use HTTPS URLs and `github-token` secret

## Troubleshooting

```bash
# Check secret exists
kubectl get secret github-deploy-key -n flux-system

# View Git source details
kubectl describe gitrepository gengine-feature -n flux-system

# Check source controller logs
kubectl logs -n flux-system deploy/source-controller -f

# Test SSH connection (from a pod)
kubectl run debug --rm -it --image=alpine/git -- ssh -T git@github.com
```

## Security Notes

- The SSH private key should be kept secure and rotated regularly
- Deploy keys have repository-specific access only
- Consider using different deploy keys for different environments
- Monitor deploy key usage in GitHub repository settings