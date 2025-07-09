# SOPS (Secrets OPerationS) Setup for Flux

## Overview

SOPS enables encrypting secrets in Git repositories while allowing Flux to decrypt them at runtime. This setup uses age encryption for simplicity and security.

## Installation

### 1. Install SOPS and age

```bash
# Install SOPS
brew install sops

# Install age for encryption
brew install age
```

### 2. Generate age Key Pair

```bash
# Generate a new age key pair
age-keygen -o ~/flux-age-key.txt

# Example output:
# # created: 2024-01-01T00:00:00Z
# # public key: age1abc123...
# AGE-SECRET-KEY-1ABC123...

# Extract the public key
grep "public key:" ~/flux-age-key.txt
```

### 3. Create SOPS Configuration

Create `.sops.yaml` in repository root:

```yaml
creation_rules:
  - path_regex: infrastructure/clusters/.*/.*\.sops\.yaml$
    age: age1abc123your_public_key_here
  - path_regex: infrastructure/apps/.*/.*\.sops\.yaml$
    age: age1abc123your_public_key_here
```

## Setup Steps

### 1. Create Age Secret in Kubernetes

```bash
# Create the age private key secret for Flux
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/flux-age-key.txt
```

### 2. Configure Flux Kustomization for Decryption

Update git-sources.yaml to include decryption configuration:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: gengine-apps-staging
  namespace: flux-system
spec:
  interval: 10m
  path: ./infrastructure/apps/overlays/staging
  prune: true
  sourceRef:
    kind: GitRepository
    name: gengine-feature
  targetNamespace: staging
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

### 3. Create Encrypted Secrets

Example workflow for creating encrypted secrets:

```bash
# Create a plain secret file
cat > secret-example.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: api-credentials
  namespace: staging
type: Opaque
stringData:
  api-key: "super-secret-api-key"
  database-url: "postgresql://user:pass@host:5432/db"
EOF

# Encrypt the secret with SOPS
sops --encrypt secret-example.yaml > secret-example.sops.yaml

# Remove the plain text file
rm secret-example.yaml

# The .sops.yaml file can now be safely committed to Git
```

## Example Encrypted Secret Files

### GitHub Webhook Token
```bash
# Create GitHub webhook secret
cat > infrastructure/clusters/staging/github-webhook-token.sops.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: github-webhook-token
  namespace: flux-system
type: Opaque
stringData:
  token: "your-actual-webhook-secret-here"
EOF

# Encrypt it
sops --encrypt infrastructure/clusters/staging/github-webhook-token.sops.yaml > infrastructure/clusters/staging/github-webhook-token.sops.yaml.tmp
mv infrastructure/clusters/staging/github-webhook-token.sops.yaml.tmp infrastructure/clusters/staging/github-webhook-token.sops.yaml
```

### Application Secrets per Environment

```bash
# Development secrets
sops --encrypt infrastructure/apps/overlays/dev/secrets.yaml > infrastructure/apps/overlays/dev/secrets.sops.yaml

# Staging secrets  
sops --encrypt infrastructure/apps/overlays/staging/secrets.yaml > infrastructure/apps/overlays/staging/secrets.sops.yaml

# Production secrets
sops --encrypt infrastructure/apps/overlays/prod/secrets.yaml > infrastructure/apps/overlays/prod/secrets.sops.yaml
```

## Verification

### Check SOPS Encryption

```bash
# View encrypted file (should show encrypted content)
cat infrastructure/clusters/staging/github-webhook-token.sops.yaml

# Decrypt and view (should show plain text)
sops --decrypt infrastructure/clusters/staging/github-webhook-token.sops.yaml
```

### Verify Flux Decryption

```bash
# Check kustomization status
flux get kustomizations

# Check if secrets are created correctly
kubectl get secrets -n staging

# Check Flux logs for decryption issues
kubectl logs -n flux-system deploy/kustomize-controller -f
```

## Security Best Practices

1. **Age Key Management**:
   - Store age private key securely (not in Git)
   - Backup age key safely
   - Rotate keys periodically

2. **SOPS Configuration**:
   - Use path-specific rules for different environments
   - Consider using different keys per environment
   - Set appropriate file patterns

3. **Git Repository**:
   - Never commit plain text secrets
   - Always verify files are encrypted before committing
   - Use pre-commit hooks to prevent plain text secrets

## Troubleshooting

### Common Issues

1. **SOPS encryption fails**:
   ```bash
   # Check SOPS configuration
   sops --help
   
   # Verify age key
   age-keygen --help
   ```

2. **Flux can't decrypt**:
   ```bash
   # Check age secret exists
   kubectl get secret sops-age -n flux-system
   
   # Check kustomization has decryption config
   kubectl describe kustomization gengine-apps-staging -n flux-system
   ```

3. **Wrong public key**:
   ```bash
   # Re-extract public key from private key
   grep "public key:" ~/flux-age-key.txt
   
   # Update .sops.yaml with correct public key
   ```

### Useful Commands

```bash
# Edit encrypted file directly
sops infrastructure/clusters/staging/secrets.sops.yaml

# Re-encrypt with new key
sops --rotate infrastructure/clusters/staging/secrets.sops.yaml

# Validate encrypted file
sops --decrypt infrastructure/clusters/staging/secrets.sops.yaml | kubectl apply --dry-run=client -f -
```

## Migration from Plain Secrets

1. Identify existing plain text secrets
2. Encrypt them with SOPS
3. Update Kustomization to use decryption
4. Remove plain text versions
5. Verify Flux can decrypt and apply

This setup ensures all secrets are encrypted at rest in Git while remaining accessible to Flux for deployment.