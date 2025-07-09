# Claude Runner Kubernetes Deployment

This document describes how to deploy and run the Claude Code CLI as a Kubernetes Job.

## Overview

The Claude Runner is designed to run as a batch job in Kubernetes, following the same pattern as the GitHub Actions implementation:
- Uses named pipes (`mkfifo`) for prompt input
- Clones the target repository
- Executes Claude Code CLI with MCP servers
- Exits after completion

## Prerequisites

- AWS CLI configured with appropriate credentials
- Docker installed and running
- kubectl configured to access your Kubernetes cluster
- ECR (Elastic Container Registry) access

## Building and Pushing the Docker Image

1. Build and push the Claude runner image to ECR:
   ```bash
   ./scripts/build-claude-runner.sh
   ```

   This script will:
   - Log in to ECR
   - Create the ECR repository if needed
   - Build the Docker image
   - Push it to ECR

2. Note the ECR image URI printed at the end (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/claude-runner:latest`)

## Deploying to Kubernetes

1. Deploy the Claude job:
   ```bash
   ./scripts/deploy-claude-job.sh
   ```

   This will:
   - Update the Job manifest with the ECR image URI
   - Apply the Kubernetes resources
   - Create example ConfigMap and Secret if needed

## Configuration

### ConfigMap Structure

The `claude-config` ConfigMap should contain:
- `job_id`: Unique job identifier
- `comment_id`: GitHub comment ID (if applicable)
- `github_repository`: Repository to clone (format: `owner/repo`)
- `github_ref`: Git ref to checkout (optional)
- `prompt`: The prompt text for Claude
- `mcp_config`: JSON configuration for MCP servers
- Various optional parameters (`allowed_tools`, `max_turns`, etc.)

### Secret Structure

The `claude-secrets` Secret must contain:
- `anthropic-api-key`: Your Anthropic API key
- `github-token`: GitHub token with appropriate permissions

## Testing

1. Create a test job:
   ```bash
   kubectl create configmap claude-config \
     --from-literal=job_id=test-123 \
     --from-literal=comment_id=test-456 \
     --from-literal=github_repository=your-org/your-repo \
     --from-literal=prompt="Please analyze the README.md file" \
     --from-file=mcp_config=mcp-config.json
   ```

2. Monitor the job:
   ```bash
   # Watch job status
   kubectl get jobs claude-job -w
   
   # View logs
   kubectl logs job/claude-job -f
   
   # Check pod status
   kubectl get pods -l app=claude-runner
   ```

3. Clean up after testing:
   ```bash
   kubectl delete job claude-job
   kubectl delete configmap claude-config
   ```

## Integration with Webhook Server

The Claude runner is designed to be triggered by the webhook server when certain GitHub events occur. The webhook server should:

1. Create a ConfigMap with the appropriate configuration
2. Create/update the Job to run Claude
3. Monitor the Job status
4. Clean up resources after completion

## Troubleshooting

### Image Pull Errors
- Ensure ECR login is valid: `aws ecr get-login-password | docker login --username AWS --password-stdin [ECR_URI]`
- Check that the image exists: `aws ecr describe-images --repository-name claude-runner`

### Job Failures
- Check logs: `kubectl logs job/claude-job`
- Verify ConfigMap: `kubectl describe configmap claude-config`
- Verify Secret: `kubectl get secret claude-secrets`

### Permission Issues
- Ensure the ServiceAccount has appropriate RBAC permissions
- Check node IAM roles for ECR access

## Environment Variables

The Claude runner respects all standard Claude Code CLI environment variables:
- `ANTHROPIC_API_KEY`: API key for Claude
- `GITHUB_TOKEN`: GitHub authentication token
- `RUNNER_TEMP`: Temporary directory (defaults to `/tmp`)
- `INPUT_*`: Various Claude configuration options