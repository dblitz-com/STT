# Local GitHub Actions Testing with Act

This guide shows how to test our CI/CD pipeline locally using [nektos/act](https://github.com/nektos/act).

## Installation

### macOS (Homebrew)
```bash
brew install act
```

### Linux/Windows
```bash
# Download latest release
curl -s https://api.github.com/repos/nektos/act/releases/latest \
  | grep "browser_download_url.*linux_amd64.tar.gz" \
  | cut -d '"' -f 4 \
  | xargs curl -L \
  | tar xz -C /usr/local/bin act
```

### From Source
```bash
git clone https://github.com/nektos/act.git
cd act
make install
```

## Configuration

### 1. Create `.actrc` file in project root:
```ini
# Use larger runner image for Docker-in-Docker
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04-full

# Environment variables
--env-file .env.local
--secret-file .secrets.local

# Local runner options
--reuse
--verbose
```

### 2. Create `.env.local` for environment variables:
```bash
# Docker configuration
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1

# Registry configuration  
REGISTRY=ghcr.io
IMAGE_NAME=devin/dblitz/gengine-rest-api

# AWS region
AWS_REGION=us-west-2

# Enable local testing mode
RUN_LOCAL=true
ACT_LOCAL=true
```

### 3. Create `.secrets.local` for secrets:
```bash
# GitHub secrets (get from GitHub settings)
GITHUB_TOKEN=ghp_your_github_token_here

# AWS credentials for infrastructure deployment
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_ACCESS_KEY_ID_PROD=your_prod_aws_access_key  
AWS_SECRET_ACCESS_KEY_PROD=your_prod_aws_secret_key

# Nomad cluster endpoints
NOMAD_ADDR_DEV=https://nomad-dev.example.com:4646
NOMAD_TOKEN_DEV=your_nomad_dev_token
NOMAD_ADDR_STAGING=https://nomad-staging.example.com:4646
NOMAD_TOKEN_STAGING=your_nomad_staging_token
NOMAD_ADDR_PROD=https://nomad-prod.example.com:4646
NOMAD_TOKEN_PROD=your_nomad_prod_token

# Notification
SLACK_WEBHOOK=https://hooks.slack.com/your/webhook/url
```

## Testing Individual Jobs

### 1. Security Scan Only
```bash
act -j security-scan --env RUN_LOCAL=true
```

### 2. Test Suite Only  
```bash
act -j test --env RUN_LOCAL=true
```

### 3. Build and Push (dry-run)
```bash
act -j build --env RUN_LOCAL=true --dry-run
```

### 4. Full CI Pipeline (no deployment)
```bash
act push --env RUN_LOCAL=true \
  --job security-scan \
  --job test \
  --job build \
  --job container-scan
```

## Testing Deployment Workflows

### Development Deployment
```bash
# Simulate push to develop branch
act push \
  --env RUN_LOCAL=true \
  --eventpath .github/events/develop-push.json \
  --job deploy-dev
```

### Staging Deployment  
```bash
# Simulate push to main branch
act push \
  --env RUN_LOCAL=true \
  --eventpath .github/events/main-push.json \
  --job deploy-staging
```

### Production Release
```bash
# Simulate release publication
act release \
  --env RUN_LOCAL=true \
  --eventpath .github/events/release-published.json \
  --job deploy-production
```

## Event Files for Testing

Create `.github/events/` directory with test event payloads:

### `.github/events/develop-push.json`
```json
{
  "ref": "refs/heads/develop",
  "repository": {
    "name": "engine",
    "full_name": "devin/dblitz"
  },
  "head_commit": {
    "id": "abc123def456",
    "message": "feat: test deployment"
  }
}
```

### `.github/events/main-push.json`
```json
{
  "ref": "refs/heads/main", 
  "repository": {
    "name": "engine",
    "full_name": "devin/dblitz"
  },
  "head_commit": {
    "id": "def456abc789",
    "message": "feat: staging deployment"
  }
}
```

### `.github/events/release-published.json`
```json
{
  "action": "published",
  "release": {
    "tag_name": "v1.0.0",
    "name": "Release v1.0.0"
  },
  "repository": {
    "name": "engine", 
    "full_name": "devin/dblitz"
  }
}
```

## Docker-in-Docker Setup

For jobs that build containers, ensure Docker daemon is accessible:

```bash
# Start Docker daemon if not running
sudo systemctl start docker

# Add user to docker group (logout/login required)
sudo usermod -aG docker $USER

# Test Docker access
docker ps
```

## Debugging Failed Jobs

### 1. Run with maximum verbosity:
```bash
act -j test --env RUN_LOCAL=true --verbose --dry-run
```

### 2. Interactive shell in failed container:
```bash
act -j test --env RUN_LOCAL=true --interactive
```

### 3. Keep containers after failure:
```bash
act -j test --env RUN_LOCAL=true --reuse --verbose
```

### 4. Use specific runner image:
```bash
act -j test \
  --env RUN_LOCAL=true \
  -P ubuntu-latest=catthehacker/ubuntu:act-22.04-full
```

## Performance Optimization

### 1. Use container reuse:
```bash
act --reuse -j test
```

### 2. Cache dependencies:
```bash
# Act will respect cache actions in workflows
# No additional configuration needed
```

### 3. Parallel job execution:
```bash
act --parallel -j security-scan -j test -j build
```

## Common Issues & Solutions

### Issue: Docker daemon not accessible
```bash
# Solution: Start Docker and check permissions
sudo systemctl start docker
sudo usermod -aG docker $USER
```

### Issue: Out of disk space
```bash
# Solution: Clean Docker resources
docker system prune -af
docker volume prune -f
```

### Issue: Network connectivity in containers
```bash
# Solution: Use host networking
act -j test --network host
```

### Issue: Missing environment variables
```bash
# Solution: Check .env.local and .secrets.local files
act -j test --env-file .env.local --secret-file .secrets.local --list
```

## Integration with Development Workflow

### Pre-commit testing:
```bash
#!/bin/bash
# .git/hooks/pre-commit
act -j security-scan -j test --env RUN_LOCAL=true
```

### CI/CD pipeline validation:
```bash
# Test full pipeline before pushing
act push --env RUN_LOCAL=true --dry-run
```

### Local development testing:
```bash
# Quick test cycle
act -j test --env RUN_LOCAL=true --reuse
```

This setup enables complete local testing of our GitHub Actions pipeline before pushing to remote repositories.