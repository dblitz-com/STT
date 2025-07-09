#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * MCP Comment Parser
 * Parses GitHub issue/PR comments to extract MCP requirements
 */
class MCPCommentParser {
  constructor(registryPath) {
    this.registry = this.loadRegistry(registryPath);
    this.patterns = this.registry.comment_patterns;
  }

  loadRegistry(registryPath) {
    try {
      const registryContent = fs.readFileSync(registryPath, 'utf8');
      return JSON.parse(registryContent);
    } catch (error) {
      console.error(`Failed to load MCP registry from ${registryPath}:`, error);
      process.exit(1);
    }
  }

  /**
   * Parse comment text to extract MCP requirements
   * @param {string} commentText - The comment text to parse
   * @returns {Object} Parsed requirements object
   */
  parseComment(commentText) {
    const requirements = {
      servers: [],
      preset: null,
      env_vars: {},
      task_description: '',
      config_template: 'standard',
      security_policy: 'default',
      raw_comment: commentText
    };

    // Clean up comment text
    const cleanText = commentText.trim();
    
    // Extract MCP servers
    const mcpServersMatch = cleanText.match(new RegExp(this.patterns.mcp_servers.pattern, 'gi'));
    if (mcpServersMatch) {
      mcpServersMatch.forEach(match => {
        const serversStr = match.replace(/@claude use mcp:/i, '');
        const servers = serversStr.split(',').map(s => s.trim());
        requirements.servers.push(...servers);
      });
    }

    // Extract preset
    const presetMatch = cleanText.match(new RegExp(this.patterns.preset.pattern, 'i'));
    if (presetMatch) {
      requirements.preset = presetMatch[1];
      // If preset is specified, add its servers
      if (this.registry.presets[requirements.preset]) {
        requirements.servers.push(...this.registry.presets[requirements.preset].servers);
      }
    }

    // Extract environment variables
    const envVarsMatch = cleanText.match(new RegExp(this.patterns.env_vars.pattern, 'gi'));
    if (envVarsMatch) {
      envVarsMatch.forEach(match => {
        const envStr = match.replace(/@claude env:/i, '');
        const envPairs = envStr.split(',');
        envPairs.forEach(pair => {
          const [key, value] = pair.split('=').map(s => s.trim());
          if (key && value) {
            requirements.env_vars[key] = value;
          }
        });
      });
    }

    // Extract task description (everything after MCP directives)
    let taskDescription = cleanText;
    
    // Remove MCP directives to get clean task description
    taskDescription = taskDescription.replace(new RegExp(this.patterns.mcp_servers.pattern, 'gi'), '');
    taskDescription = taskDescription.replace(new RegExp(this.patterns.preset.pattern, 'gi'), '');
    taskDescription = taskDescription.replace(new RegExp(this.patterns.env_vars.pattern, 'gi'), '');
    
    requirements.task_description = taskDescription.trim();

    // Determine config template based on number of servers
    const uniqueServers = [...new Set(requirements.servers)];
    if (uniqueServers.length <= 2) {
      requirements.config_template = 'minimal';
    } else if (uniqueServers.length <= 5) {
      requirements.config_template = 'standard';
    } else {
      requirements.config_template = 'comprehensive';
    }

    // Remove duplicates
    requirements.servers = uniqueServers;

    return requirements;
  }

  /**
   * Validate that all required servers exist in registry
   * @param {Array} servers - Array of server names
   * @returns {Object} Validation result
   */
  validateServers(servers) {
    const validation = {
      valid: true,
      invalid_servers: [],
      missing_env_vars: [],
      conflicts: []
    };

    servers.forEach(serverName => {
      if (!this.registry.registry[serverName]) {
        validation.valid = false;
        validation.invalid_servers.push(serverName);
      }
    });

    // Check for server conflicts
    const serverConfigs = servers.map(name => this.registry.registry[name]).filter(Boolean);
    serverConfigs.forEach(config => {
      if (config.conflicts) {
        config.conflicts.forEach(conflictServer => {
          if (servers.includes(conflictServer)) {
            validation.valid = false;
            validation.conflicts.push(`${config.name} conflicts with ${conflictServer}`);
          }
        });
      }
    });

    return validation;
  }

  /**
   * Generate MCP configuration JSON
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} MCP configuration
   */
  generateMCPConfig(requirements) {
    const validation = this.validateServers(requirements.servers);
    
    if (!validation.valid) {
      throw new Error(`Invalid MCP configuration: ${JSON.stringify(validation, null, 2)}`);
    }

    const mcpConfig = {
      mcpServers: {},
      tools: {},
      environment: requirements.env_vars,
      config_template: requirements.config_template
    };

    // Add servers to configuration
    requirements.servers.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      if (serverConfig) {
        mcpConfig.mcpServers[serverName] = {
          command: serverConfig.server_config.command,
          args: serverConfig.server_config.args,
          env: { ...serverConfig.server_config.env, ...requirements.env_vars }
        };

        // Add tools
        serverConfig.tools.forEach(tool => {
          mcpConfig.tools[tool] = {
            server: serverName,
            description: `${tool} from ${serverConfig.name}`
          };
        });
      }
    });

    return mcpConfig;
  }

  /**
   * Generate allowed tools list for Claude Code Actions
   * @param {Array} servers - Array of server names
   * @returns {Array} Array of allowed tools
   */
  generateAllowedTools(servers) {
    const allowedTools = new Set();
    
    // Add default tools
    const defaultTools = ['read', 'write', 'bash', 'git'];
    defaultTools.forEach(tool => allowedTools.add(tool));

    // Add server-specific tools
    servers.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      if (serverConfig) {
        serverConfig.tools.forEach(tool => allowedTools.add(tool));
      }
    });

    return Array.from(allowedTools);
  }

  /**
   * Generate GitHub Actions workflow configuration
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} GitHub Actions configuration
   */
  generateGitHubActionsConfig(requirements) {
    const mcpConfig = this.generateMCPConfig(requirements);
    const allowedTools = this.generateAllowedTools(requirements.servers);
    const template = this.registry.config_templates[requirements.config_template];

    return {
      mcp_config: JSON.stringify(mcpConfig, null, 2),
      allowed_tools: allowedTools.join(','),
      timeout: template.timeout,
      resource_limits: template.resource_limits,
      servers: requirements.servers,
      task_description: requirements.task_description,
      preset: requirements.preset,
      environment: requirements.env_vars
    };
  }

  /**
   * Generate comprehensive configuration report
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} Configuration report
   */
  generateReport(requirements) {
    const validation = this.validateServers(requirements.servers);
    const mcpConfig = validation.valid ? this.generateMCPConfig(requirements) : null;
    const allowedTools = validation.valid ? this.generateAllowedTools(requirements.servers) : [];
    const githubConfig = validation.valid ? this.generateGitHubActionsConfig(requirements) : null;

    return {
      parsed_requirements: requirements,
      validation,
      mcp_config: mcpConfig,
      allowed_tools: allowedTools,
      github_actions_config: githubConfig,
      timestamp: new Date().toISOString()
    };
  }
}

// CLI Interface
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.error('Usage: node mcp-comment-parser.js <registry-path> <comment-text>');
    console.error('   or: node mcp-comment-parser.js <registry-path> --file <comment-file>');
    process.exit(1);
  }

  const registryPath = args[0];
  let commentText = '';

  if (args[1] === '--file') {
    if (args.length < 3) {
      console.error('Error: --file option requires a file path');
      process.exit(1);
    }
    try {
      commentText = fs.readFileSync(args[2], 'utf8');
    } catch (error) {
      console.error(`Error reading file ${args[2]}:`, error.message);
      process.exit(1);
    }
  } else {
    commentText = args.slice(1).join(' ');
  }

  const parser = new MCPCommentParser(registryPath);
  const requirements = parser.parseComment(commentText);
  const report = parser.generateReport(requirements);

  // Output format based on environment
  if (process.env.GITHUB_ACTIONS) {
    // GitHub Actions output format
    console.log(`::set-output name=mcp_config::${report.github_actions_config?.mcp_config || '{}'}`);
    console.log(`::set-output name=allowed_tools::${report.github_actions_config?.allowed_tools || ''}`);
    console.log(`::set-output name=servers::${JSON.stringify(requirements.servers)}`);
    console.log(`::set-output name=task_description::${requirements.task_description}`);
    console.log(`::set-output name=valid::${report.validation.valid}`);
    
    if (!report.validation.valid) {
      console.log(`::error::Invalid MCP configuration: ${JSON.stringify(report.validation)}`);
      process.exit(1);
    }
  } else {
    // Pretty print for local development
    console.log(JSON.stringify(report, null, 2));
  }
}

module.exports = MCPCommentParser;