# Claude Code Environment Setup Guide

## Quick Setup Instructions

### 1. Create your `.env` file
Create a new file named `.env` in the project root directory:

```bash
touch .env
```

### 2. Add your Anthropic API Key
Open the `.env` file and add your Anthropic API key:

```bash
# Required: Your Anthropic API key
ANTHROPIC_API_KEY=your_actual_anthropic_api_key_here
```

### 3. Optional: Add additional configuration
You can add any of these optional environment variables to customize Claude Code's behavior:

```bash
# Custom model override (default uses Claude 3.5 Sonnet)
ANTHROPIC_MODEL=claude-3-5-sonnet-20241022

# Small/fast model for background tasks (default uses Haiku)
ANTHROPIC_SMALL_FAST_MODEL=claude-3-haiku-20240307

# GitHub token for enhanced functionality
GITHUB_TOKEN=your_github_token_here

# Disable features for local development
DISABLE_TELEMETRY=1
DISABLE_AUTOUPDATER=1
DISABLE_ERROR_REPORTING=1

# Bash command settings
BASH_DEFAULT_TIMEOUT_MS=30000
BASH_MAX_TIMEOUT_MS=300000
BASH_MAX_OUTPUT_LENGTH=10000

# Model Context Protocol (MCP) settings
MCP_TIMEOUT=10000
MCP_TOOL_TIMEOUT=30000
MAX_MCP_OUTPUT_TOKENS=25000

# Proxy settings (if behind corporate proxy)
HTTP_PROXY=http://proxy.example.com:8080
HTTPS_PROXY=https://proxy.example.com:8080

# Force maximum output tokens
CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096

# Maintain working directory between commands
CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1
```

## Alternative Configuration Methods

### Using settings.json (Recommended)
Claude Code also supports configuration via `settings.json` files:

#### User settings (applies to all projects)
```bash
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_API_KEY": "your_actual_anthropic_api_key_here",
    "DISABLE_TELEMETRY": "1"
  },
  "model": "claude-3-5-sonnet-20241022",
  "permissions": {
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test:*)",
      "Read(~/.zshrc)"
    ]
  }
}
EOF
```

#### Project settings (checked into source control)
```bash
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "30000",
    "MCP_TIMEOUT": "10000"
  },
  "permissions": {
    "allow": [
      "Bash(git diff:*)",
      "Bash(npm run:*)"
    ]
  }
}
EOF
```

#### Local project settings (not checked into source control)
```bash
mkdir -p .claude
cat > .claude/settings.local.json << 'EOF'
{
  "env": {
    "ANTHROPIC_API_KEY": "your_actual_anthropic_api_key_here"
  }
}
EOF
```

## Getting Your Anthropic API Key

1. Go to [Anthropic Console](https://console.anthropic.com/)
2. Sign in or create an account
3. Navigate to "API Keys"
4. Create a new API key
5. Copy the key and paste it into your `.env` file

## Testing Your Setup

1. Create your `.env` file with your API key
2. Run Claude Code in your project
3. Try a simple command like `/config` to verify it's working

## Security Notes

- Never commit `.env` files to version control
- The `.env` file is already in `.gitignore` for security
- Use `.claude/settings.local.json` for local-only settings
- Use `.claude/settings.json` for team-shared settings (without secrets)

## Current Project Integration

Your project already has:
- ✅ Kubernetes integration with secrets
- ✅ GitHub webhook automation
- ✅ Docker containers for Claude Code
- ✅ Proper secret management for production

The `.env` file is for local development and testing only. 