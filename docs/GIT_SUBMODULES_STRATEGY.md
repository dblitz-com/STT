# Git Submodules Strategy for GenEngine

## Overview

Based on research and best practices for 2024/2025, this document outlines our comprehensive strategy for handling Git submodules in the GenEngine project across Docker builds, CI/CD pipelines, and Nomad deployment.

## Current Architecture

GenEngine uses Git submodules for:
- `src/gengines/gengine-rest-api-to-mcp` - REST API server for converting repositories to MCP
- `src/gengines/gengine-mcp-catalog` - MCP catalog server
- Future gengines as they are developed

## Git Submodules Best Practices Implementation

### 1. Repository Structure
```
engine/                           # Main repository
├── src/gengines/                # Submodules directory
│   ├── gengine-rest-api-to-mcp/ # Submodule: REST API server
│   └── gengine-mcp-catalog/     # Submodule: MCP catalog
├── .gitmodules                  # Submodule configuration
├── infrastructure/              # Deployment infrastructure
└── .github/workflows/           # CI/CD pipelines
```

### 2. CI/CD Pipeline Strategy

#### GitHub Actions Configuration
Our CI/CD pipeline already includes proper submodule handling:

```yaml
# In .github/workflows/ci-cd.yml
- name: Checkout code with submodules
  uses: actions/checkout@v4
  with:
    submodules: recursive  # Recursively checkout all submodules
    fetch-depth: 0         # Full history for proper Git operations
    token: ${{ secrets.GITHUB_TOKEN }}
```

#### Key Features:
- **Recursive checkout**: Ensures all nested submodules are fetched
- **Full history**: Required for proper version tagging and releases
- **Automated authentication**: Uses GITHUB_TOKEN for submodule access

### 3. Docker Build Strategy

#### Multi-Stage Docker Builds
Each gengine uses a multi-stage build approach:

```dockerfile
# Example from gengine-rest-api-to-mcp/Dockerfile
FROM python:3.11-slim as base

# Dependencies layer
FROM base as dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application layer  
FROM dependencies as app
WORKDIR /app
COPY --chown=gengine:gengine api/ ./api/
CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Key Principles:
- **Bake all submodule code into images**: No runtime Git operations needed
- **Layer optimization**: Dependencies and code in separate layers
- **Security**: No Git credentials or `.git` directories in final images

### 4. Version Management Strategy

#### Synchronized Tagging
```bash
# Script for coordinated releases
#!/bin/bash
# 1. Tag submodules first
cd src/gengines/gengine-rest-api-to-mcp
git tag v1.2.3
git push origin v1.2.3

cd ../gengine-mcp-catalog  
git tag v1.2.3
git push origin v1.2.3

# 2. Update submodule pointers in main repo
cd ../../..
git add src/gengines/
git commit -m "Update submodules to v1.2.3"

# 3. Tag main repository
git tag v1.2.3
git push origin v1.2.3
```

#### Automated in CI/CD:
Our GitHub Actions workflow automates this process:
- Submodules are tagged first
- Main repository submodule pointers are updated
- Main repository is tagged
- Docker images are built and tagged with the same version

### 5. Local Development Setup

#### Initial Clone
```bash
# Clone with all submodules
git clone --recurse-submodules https://github.com/your-org/engine.git

# Or if already cloned
git submodule update --init --recursive
```

#### Daily Development
```bash
# Update all submodules to latest
git submodule update --remote --recursive

# Work on a specific submodule
cd src/gengines/gengine-rest-api-to-mcp
git checkout -b feature/new-endpoint
# Make changes...
git commit -m "Add new endpoint"
git push origin feature/new-endpoint

# Update main repo to point to new commit
cd ../../..
git add src/gengines/gengine-rest-api-to-mcp
git commit -m "Update gengine-rest-api-to-mcp to feature/new-endpoint"
```

### 6. Nomad Deployment Strategy

#### Container-Based Deployment
All deployed containers include baked-in submodule code:

```hcl
# nomad/jobs/gengine-rest-api.nomad
job "gengine-rest-api" {
  datacenters = ["dc1"]
  
  group "api" {
    task "rest-api" {
      driver = "docker"
      
      config {
        image = "gengine/rest-api:${version}"
        # No Git operations needed - all code is baked in
      }
      
      # Health checks, service mesh, etc.
    }
  }
}
```

#### Key Benefits:
- **No Git dependencies at runtime**: Containers are self-contained
- **Consistent deployments**: Same image across environments
- **Fast startup**: No Git clone/checkout delays
- **Secure**: No Git credentials needed in production

### 7. Security Considerations

#### CI/CD Access Control
```yaml
# GitHub Actions permissions
permissions:
  contents: read          # Read repository content
  packages: write         # Push Docker images
  id-token: write        # OIDC for AWS authentication
```

#### Submodule Access
- Use GITHUB_TOKEN for public repositories
- Use PAT (Personal Access Token) for private submodules:
```yaml
- name: Checkout with private submodules
  uses: actions/checkout@v4
  with:
    submodules: recursive
    token: ${{ secrets.SUBMODULE_PAT }}
```

### 8. Testing Strategy

#### Multi-Repository Testing
```yaml
# In our CI pipeline
- name: Test main repository
  run: |
    npm test
    
- name: Test submodules
  run: |
    cd src/gengines/gengine-rest-api-to-mcp
    python -m pytest
    
    cd ../gengine-mcp-catalog
    npm test
```

#### Integration Testing
- Test submodule APIs individually
- Test inter-service communication
- Test complete workflows end-to-end

### 9. Monitoring and Observability

#### Version Tracking
Each deployed service includes submodule version information:
```json
{
  "service": "gengine-rest-api",
  "version": "1.2.3",
  "submodule_commit": "abc123def456",
  "build_time": "2024-07-05T12:00:00Z"
}
```

#### Health Checks
Nomad health checks verify both service functionality and version consistency.

### 10. Migration from Alternatives

#### Why Submodules vs Monorepo
**Pros of Submodules:**
- Independent versioning of gengines
- Smaller clone sizes for individual components
- Clear separation of concerns
- Ability to share gengines across projects

**Pros of Monorepo:**
- Simpler dependency management
- Atomic changes across services
- Single CI/CD pipeline
- No submodule complexity

**Our Choice:** Submodules for modularity while using infrastructure automation to manage complexity.

### 11. Troubleshooting Common Issues

#### Submodule Out of Sync
```bash
# Update submodule to latest commit
git submodule update --remote src/gengines/gengine-rest-api-to-mcp

# Commit the update
git add .gitmodules src/gengines/gengine-rest-api-to-mcp
git commit -m "Update submodule to latest"
```

#### CI/CD Submodule Failures
- Ensure `submodules: recursive` in checkout action
- Verify access permissions for private repositories
- Check submodule URL configuration (HTTPS vs SSH)

#### Docker Build Issues
- Ensure all submodules are updated before Docker build
- Use `.dockerignore` to exclude `.git` directories
- Verify file paths in Dockerfile match submodule structure

## Implementation Status

✅ **Completed:**
- Multi-stage Docker builds with submodule support
- GitHub Actions workflow with recursive submodule checkout
- Nomad job specifications for containerized deployment
- Version management strategy
- Local development documentation

🚀 **Next Steps:**
1. Deploy infrastructure to AWS
2. Test end-to-end submodule workflow
3. Add automated submodule update monitoring
4. Implement cross-submodule integration tests

## Conclusion

This strategy leverages modern best practices for 2024/2025, ensuring our Git submodules are properly managed across the entire development and deployment lifecycle. The approach prioritizes security, automation, and maintainability while preserving the modularity benefits of submodules.