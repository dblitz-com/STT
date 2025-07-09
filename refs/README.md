# Official Claude Code Action References

This directory contains the official Anthropic Claude Code Action implementations for reference.

## Repositories

### `claude-code-action/`
- **Official GitHub Action**: High-level Claude Code Action wrapper
- **Repository**: https://github.com/anthropics/claude-code-action  
- **Purpose**: Main action that users add to their GitHub workflows
- **Features**: Trigger detection, context gathering, GitHub integration

### `claude-code-base-action/`
- **Official Base Action**: Low-level Claude CLI executor
- **Repository**: https://github.com/anthropics/claude-code-base-action
- **Purpose**: Core Claude Code execution engine
- **Features**: MCP server management, prompt handling, model interaction

## Preferred Implementation (Option A)

**Use GitHub Actions self-hosted runners** with these official actions:

1. Deploy actions-runner-controller (ARC) in Kubernetes
2. Configure auto-scaling runners (minimum 1, scale on demand)  
3. Use official `claude-code-action` workflow exactly as designed
4. Proper GitHub status comments automatically work
5. Better GitHub ecosystem integration

## Custom Implementation (Option B)

⚠️ **DO NOT USE UNLESS FIXING GITHUB ACTIONS RUNNER ISSUES!**

The custom Kubernetes implementation in `src/coding/claudecode/` should only be used for:
- Debugging GitHub Actions runner problems
- Development/testing when runners unavailable
- Understanding the workflow mechanics

**Issues with Option B:**
- Missing GitHub Actions context variables
- Incorrect status comment formatting  
- Complex maintenance overhead
- No automatic scaling benefits

## Next Steps

1. Review official implementations in these directories
2. Set up GitHub Actions self-hosted runners (Option A)
3. Phase out custom Kubernetes implementation (Option B)
4. Update webhook handler to trigger GitHub Actions workflows