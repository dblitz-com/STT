# Test Deployment

This file is created to test the automatic deployment webhook.

When pushed to the dev branch, the webhook should:
1. Update all submodules to their latest commits
2. Build the gengine-rest-api-to-mcp Docker image
3. Push it to ECR
4. Deploy via Terragrunt/App Runner

Timestamp: 2025-07-05T21:52:00Z