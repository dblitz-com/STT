# MCP Catalog Server

A dynamic catalog server for Model Context Protocol (MCP) that acts as a universal wrapper, automatically discovering and exposing tools from multiple configured MCP servers through a single entry point.

## Features

- 🔍 **Dynamic Tool Discovery**: Automatically discovers tools from configured MCP servers
- 🚀 **Single Entry Point**: Replace all individual MCP server entries with one catalog
- 🔧 **Meta Tools**: Built-in tools for server discovery and management
- 📦 **Multiple Installation Methods**: pip, uvx, Docker, or source
- ⚙️ **Smart Configuration**: Hierarchical config with environment variables and auto-discovery
- 🐳 **Production Ready**: Docker support for enterprise deployments
- 🎛️ **Fine-Grained Control**: Enable/disable specific servers and tools via configuration

## Quick Start

### Install via pip

```bash
pip install mcp-catalog-server
```

### Install via uvx (zero-install)

```bash
uvx mcp-catalog-server serve
```

### Initialize Configuration

```bash
mcp-catalog-server init
```

This creates a `~/.mcp/` directory with:
- `config.json` - Main configuration
- `.env` - Environment variables for API keys
- `custom_registry.json` - Optional custom server definitions

### Add Custom MCP Servers (Optional)

The catalog includes popular MCP servers by default. To add custom servers, create `~/.mcp/custom_registry.json`:

```json
{
  "my-custom-server": {
    "id": "custom/my-server",
    "name": "my-custom-server",
    "description": "My custom MCP server",
    "package": {
      "name": "my-mcp-server",
      "registry": "npm",
      "version": "latest"
    },
    "config": {
      "env": {
        "API_KEY": {
          "required": true,
          "description": "API key for my service"
        }
      },
      "args": []
    },
    "categories": ["custom"]
  }
}
```

### Start the Server

```bash
mcp-catalog-server serve
```

## Configuration

### Configuration Hierarchy

Configuration is loaded from multiple sources (highest to lowest priority):

1. Command-line arguments
2. Environment variables (`MCP_CATALOG_*`)
3. User config (`~/.mcp/config.json`)
4. Project config (`.mcp.json` in current directory)
5. Built-in defaults

### Environment Variables

```bash
# Server configuration
export MCP_CATALOG_HOST=localhost
export MCP_CATALOG_PORT=3000
export MCP_CATALOG_LOG_LEVEL=INFO

# Python configuration
export MCP_CATALOG_PYTHON=/path/to/python

# Auto-discovery
export MCP_CATALOG_AUTO_DISCOVER=true

# Server and Tool Control
export MCP_CATALOG_ENABLED_SERVERS=context7,perplexity-ask  # Only enable specific servers
export MCP_CATALOG_ENABLED_SERVERS=*                       # Enable all servers (default)
export MCP_CATALOG_DISABLED_TOOLS=taskmaster-ai_research,perplexity-ask_perplexity_ask  # Disable specific tools
```

### Example Configuration

```json
{
  "server": {
    "host": "localhost",
    "port": 3000,
    "log_level": "INFO"
  },
  "paths": {
    "logs": "~/.mcp/logs",
    "cache": "~/.mcp/cache"
  },
  "discovery": {
    "auto_discover": true
  }
}
```

## Docker Deployment

### Using Docker

```bash
docker run -p 3000:3000 \
  -v ~/.mcp:/root/.mcp \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  mcp-catalog-server
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  mcp-catalog:
    image: mcp-catalog-server
    ports:
      - "3000:3000"
    volumes:
      - ~/.mcp:/root/.mcp
    env_file:
      - .env
```

## CLI Commands

### List Available Servers

```bash
mcp-catalog-server list
mcp-catalog-server list --format json
```

### Check Server Configuration

```bash
mcp-catalog-server check github
```

### Show Current Configuration

```bash
mcp-catalog-server config
mcp-catalog-server config --sources  # Show where each value comes from
```

## Meta Tools

The catalog server provides built-in tools for management:

- `list_available_servers()` - List all configured MCP servers
- `check_server_requirements(server_name)` - Check environment requirements
- `list_all_tools()` - Browse all available tools
- `search_tools(query)` - Search for tools by keyword
- `get_tool_details(tool_name)` - Get detailed tool documentation
- `refresh_configuration()` - Reload configuration from local registry

## Server and Tool Control

The MCP Catalog Server provides fine-grained control over which servers and tools are exposed to Claude Desktop.

### Enabling Specific Servers

Control which servers are active using the `MCP_CATALOG_ENABLED_SERVERS` environment variable:

```bash
# Enable only specific servers
export MCP_CATALOG_ENABLED_SERVERS=context7,perplexity-ask,taskmaster-ai

# Enable all servers (default)
export MCP_CATALOG_ENABLED_SERVERS=*
```

Or in your `.mcp.json`:

```json
{
  "mcpServers": {
    "mcp-catalog": {
      "command": "python",
      "args": ["-m", "mcp_catalog_server"],
      "env": {
        "MCP_CATALOG_ENABLED_SERVERS": "context7,perplexity-ask"
      }
    }
  }
}
```

### Disabling Specific Tools

Disable problematic or unwanted tools using the `MCP_CATALOG_DISABLED_TOOLS` environment variable:

```bash
# Disable specific tools (use the full proxy name or just the tool name)
export MCP_CATALOG_DISABLED_TOOLS=taskmaster-ai_research,perplexity-ask_perplexity_ask

# Or just the tool names
export MCP_CATALOG_DISABLED_TOOLS=research,perplexity_ask
```

### Checking Current Configuration

Use the `get_server_configuration` tool to see current settings:

```
Tool: get_server_configuration

Returns:
{
  "control_settings": {
    "enabled_servers": "context7,perplexity-ask",
    "disabled_tools": "research",
    "configuration_info": {
      "MCP_CATALOG_ENABLED_SERVERS": "Comma-separated list of servers to enable, or '*' for all",
      "MCP_CATALOG_DISABLED_TOOLS": "Comma-separated list of tools to disable"
    }
  },
  "available_servers": [...],
  "enabled_servers": [...]
}
```

## Development

### Install from Source

```bash
git clone https://github.com/yourusername/mcp-catalog-server
cd mcp-catalog-server
pip install -e .
```

### Run Tests

```bash
pytest tests/
```

## Migration from Individual Servers

If you're currently using individual MCP server entries in your `.mcp.json`:

1. Install the package: `pip install mcp-catalog-server`
2. Initialize config: `mcp-catalog-server init`
3. Add any custom servers to `~/.mcp/custom_registry.json` (optional)
4. Update your Claude Desktop config to use only the catalog server
5. Remove individual server entries - the catalog includes popular servers by default

## License

MIT License - see LICENSE file for details.# Testing branch promotion trigger
