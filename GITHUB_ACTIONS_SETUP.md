# 🎉 Claude Code with Self-Hosted Runners - SIMPLE VERSION

## What We Actually Need (SO Much Simpler!)

You were absolutely right! Once we have GitHub Actions self-hosted runners, we can **delete ALL custom infrastructure** and just use:

1. ✅ **Self-hosted runners** in Kubernetes
2. ✅ **Official claude-code-action** workflow (20 lines!)
3. ✅ **GitHub's native webhooks** (automatic!)

## Two Options Available

### 🌟 OPTION A: Official Claude Code Action (DEFAULT/RECOMMENDED)
✅ **Self-hosted runners** in Kubernetes  
✅ **Official claude-code-action** workflow (20 lines!)  
✅ **GitHub's native webhooks** (automatic!)  
✅ **No custom infrastructure** needed  

### 🔧 OPTION B: Custom Claude Infrastructure (PRESERVED)
✅ **Custom webhook handlers** (for learning/customization)  
✅ **Kubernetes Job creation** (direct cluster execution)  
✅ **Custom MCP servers** (for specialized workflows)  
✅ **Complex webhook routing** (for advanced use cases)  
✅ **All the infrastructure we built** (valuable for future!)

## The Beautiful Simple Flow

```
@claude comment → GitHub webhook → Workflow → Self-hosted runner → Official action → ✨
```

1. Someone comments `@claude` on issue/PR
2. GitHub's **native webhook** automatically triggers workflow
3. Workflow runs on our **self-hosted runners**
4. **Official claude-code-action** handles everything
5. Perfect status comments appear automatically

## Current Status

### ✅ Self-Hosted Runners 
```bash
kubectl get autoscalingrunnerset -n actions-runner-system
# NAME             MINIMUM   MAXIMUM   CURRENT   STATE
# claude-runners   1         3
```

### ✅ Simple Workflow
```yaml
# .github/workflows/claude-code.yml
name: Claude Code Action
on:
  issue_comment:
    types: [created]
jobs:
  claude-code:
    runs-on: [self-hosted, linux, x64]
    if: github.event.issue_comment.body contains '@claude'
    steps:
    - uses: anthropics/claude-code-action@v1
      with:
        anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
        github_token: ${{ secrets.GITHUB_TOKEN }}
```

### ✅ No Infrastructure Needed!
```yaml
# infrastructure/apps/base/kustomization.yaml
resources:
  # 🎉 NO CUSTOM INFRASTRUCTURE NEEDED! 🎉
  # GitHub's native webhooks handle everything!
```

## Next Steps

1. **Wait for runners to start** (controller is starting up)
2. **Test with @claude comment** on an issue  
3. **Delete all custom infrastructure** once confirmed working
4. **Celebrate the simplicity!** 🎉

## Custom Infrastructure (Option B)

**PRESERVED** for future use, learning, and custom implementations:
- `src/coding/entrypoints/webhook-*.ts` ✅ **Kept for custom workflows**
- `infrastructure/apps/base/webhook-*.yaml` ✅ **Kept for advanced setups**  
- `infrastructure/apps/base/claude-job.yaml` ✅ **Kept for direct K8s execution**
- `src/coding/claudecode/` implementation ✅ **Kept for customization**

To enable Option B, simply uncomment the resources in `infrastructure/apps/base/kustomization.yaml`

## The Lesson

Sometimes the simplest solution is the best solution. Official tools + native integrations > custom infrastructure.

This is exactly how Claude Code should be used! 🚀