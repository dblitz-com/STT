#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const MCPCommentParser = require('./mcp-comment-parser');

/**
 * Dynamic MCP Configuration Builder
 * Generates Claude Code Actions compatible MCP configurations
 */
class MCPConfigBuilder {
  constructor(registryPath) {
    this.parser = new MCPCommentParser(registryPath);
    this.registry = this.parser.registry;
  }

  /**
   * Build complete MCP configuration for Claude Code Actions
   * @param {Object} requirements - Parsed comment requirements
   * @returns {Object} Complete MCP configuration
   */
  buildConfiguration(requirements) {
    const validation = this.parser.validateServers(requirements.servers);
    
    if (!validation.valid) {
      throw new Error(`Configuration validation failed: ${JSON.stringify(validation, null, 2)}`);
    }

    const config = {
      version: '1.0.0',
      claude_config: this.buildClaudeConfig(requirements),
      mcp_config: this.buildMCPConfig(requirements),
      environment: this.buildEnvironmentConfig(requirements),
      security: this.buildSecurityConfig(requirements),
      metadata: this.buildMetadata(requirements)
    };

    return config;
  }

  /**
   * Build Claude Code Actions specific configuration
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} Claude configuration
   */
  buildClaudeConfig(requirements) {
    const allowedTools = this.parser.generateAllowedTools(requirements.servers);
    const template = this.registry.config_templates[requirements.config_template];
    const securityPolicy = this.registry.security_policies[requirements.security_policy];

    return {
      allowed_tools: allowedTools.filter(tool => 
        !securityPolicy.restricted_tools.includes(tool)
      ),
      timeout: template.timeout,
      max_iterations: 50,
      task_description: requirements.task_description,
      context: {
        servers: requirements.servers,
        preset: requirements.preset,
        config_template: requirements.config_template
      }
    };
  }

  /**
   * Build MCP server configuration
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} MCP server configuration
   */
  buildMCPConfig(requirements) {
    const mcpServers = {};
    const resolvedDependencies = this.resolveDependencies(requirements.servers);

    resolvedDependencies.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      if (serverConfig) {
        mcpServers[serverName] = {
          command: serverConfig.server_config.command,
          args: serverConfig.server_config.args,
          env: this.buildServerEnvironment(serverConfig, requirements.env_vars),
          options: {
            timeout: 30000,
            retries: 3,
            health_check: true
          }
        };
      }
    });

    return {
      mcpServers,
      server_startup_order: this.calculateStartupOrder(resolvedDependencies),
      health_checks: this.buildHealthChecks(resolvedDependencies)
    };
  }

  /**
   * Build environment configuration
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} Environment configuration
   */
  buildEnvironmentConfig(requirements) {
    const envConfig = {
      user_provided: requirements.env_vars,
      github_secrets: this.extractGitHubSecrets(requirements.servers),
      computed: {
        TIMESTAMP: new Date().toISOString(),
        CONFIG_TEMPLATE: requirements.config_template,
        SERVERS: requirements.servers.join(','),
        TASK_HASH: this.generateTaskHash(requirements.task_description)
      }
    };

    return envConfig;
  }

  /**
   * Build security configuration
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} Security configuration
   */
  buildSecurityConfig(requirements) {
    const securityPolicy = this.registry.security_policies[requirements.security_policy];
    const serverTools = this.getServerTools(requirements.servers);

    return {
      policy: requirements.security_policy,
      allowed_tools: serverTools.filter(tool => 
        !securityPolicy.restricted_tools.includes(tool)
      ),
      restricted_tools: securityPolicy.restricted_tools,
      require_approval: securityPolicy.require_approval,
      audit_log: true,
      session_timeout: 3600,
      max_file_size: '10MB',
      allowed_file_types: ['.js', '.ts', '.py', '.go', '.rs', '.yaml', '.yml', '.json', '.md', '.txt'],
      sandbox_mode: true
    };
  }

  /**
   * Build metadata for tracking and debugging
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} Metadata configuration
   */
  buildMetadata(requirements) {
    return {
      created_at: new Date().toISOString(),
      parser_version: '1.0.0',
      registry_version: this.registry.version,
      raw_comment: requirements.raw_comment,
      parsed_servers: requirements.servers,
      resolved_dependencies: this.resolveDependencies(requirements.servers),
      config_source: 'dynamic_comment_parsing',
      github_context: {
        repository: process.env.GITHUB_REPOSITORY,
        ref: process.env.GITHUB_REF,
        sha: process.env.GITHUB_SHA,
        actor: process.env.GITHUB_ACTOR,
        workflow: process.env.GITHUB_WORKFLOW
      }
    };
  }

  /**
   * Resolve server dependencies
   * @param {Array} servers - Array of server names
   * @returns {Array} Array of servers with dependencies resolved
   */
  resolveDependencies(servers) {
    const resolved = new Set();
    const visited = new Set();

    const resolveDeps = (serverName) => {
      if (visited.has(serverName)) return;
      visited.add(serverName);

      const serverConfig = this.registry.registry[serverName];
      if (!serverConfig) return;

      // Resolve dependencies first
      if (serverConfig.dependencies) {
        serverConfig.dependencies.forEach(dep => {
          if (!resolved.has(dep)) {
            resolveDeps(dep);
          }
        });
      }

      resolved.add(serverName);
    };

    servers.forEach(server => resolveDeps(server));
    return Array.from(resolved);
  }

  /**
   * Calculate optimal server startup order
   * @param {Array} servers - Array of server names
   * @returns {Array} Ordered array of servers
   */
  calculateStartupOrder(servers) {
    const order = [];
    const dependencyMap = new Map();

    // Build dependency map
    servers.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      dependencyMap.set(serverName, serverConfig.dependencies || []);
    });

    // Topological sort
    const visited = new Set();
    const temp = new Set();

    const visit = (serverName) => {
      if (temp.has(serverName)) {
        throw new Error(`Circular dependency detected involving ${serverName}`);
      }
      if (visited.has(serverName)) return;

      temp.add(serverName);
      const deps = dependencyMap.get(serverName) || [];
      deps.forEach(dep => visit(dep));
      temp.delete(serverName);
      visited.add(serverName);
      order.push(serverName);
    };

    servers.forEach(server => visit(server));
    return order;
  }

  /**
   * Build health checks for servers
   * @param {Array} servers - Array of server names
   * @returns {Object} Health check configuration
   */
  buildHealthChecks(servers) {
    const healthChecks = {};

    servers.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      if (serverConfig) {
        healthChecks[serverName] = {
          enabled: true,
          interval: 30,
          timeout: 5,
          retries: 3,
          check_tools: serverConfig.tools.slice(0, 2) // Check first 2 tools
        };
      }
    });

    return healthChecks;
  }

  /**
   * Build server-specific environment variables
   * @param {Object} serverConfig - Server configuration
   * @param {Object} userEnvVars - User-provided environment variables
   * @returns {Object} Environment variables for the server
   */
  buildServerEnvironment(serverConfig, userEnvVars) {
    const serverEnv = { ...serverConfig.server_config.env };
    
    // Substitute user-provided variables
    Object.keys(serverEnv).forEach(key => {
      const value = serverEnv[key];
      if (typeof value === 'string' && value.startsWith('${') && value.endsWith('}')) {
        const envVar = value.slice(2, -1);
        if (userEnvVars[envVar]) {
          serverEnv[key] = userEnvVars[envVar];
        } else {
          // Keep the variable for GitHub Actions to substitute
          serverEnv[key] = `\${{ secrets.${envVar} }}`;
        }
      }
    });

    return serverEnv;
  }

  /**
   * Extract GitHub secrets needed for servers
   * @param {Array} servers - Array of server names
   * @returns {Array} Array of required GitHub secrets
   */
  extractGitHubSecrets(servers) {
    const secrets = new Set();

    servers.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      if (serverConfig) {
        serverConfig.required_env.forEach(env => secrets.add(env));
        serverConfig.optional_env.forEach(env => secrets.add(env));
      }
    });

    return Array.from(secrets);
  }

  /**
   * Get all tools provided by servers
   * @param {Array} servers - Array of server names
   * @returns {Array} Array of tool names
   */
  getServerTools(servers) {
    const tools = new Set();

    servers.forEach(serverName => {
      const serverConfig = this.registry.registry[serverName];
      if (serverConfig) {
        serverConfig.tools.forEach(tool => tools.add(tool));
      }
    });

    return Array.from(tools);
  }

  /**
   * Generate a hash for the task description
   * @param {string} taskDescription - Task description
   * @returns {string} Hash of the task
   */
  generateTaskHash(taskDescription) {
    const crypto = require('crypto');
    return crypto.createHash('md5').update(taskDescription).digest('hex').substring(0, 8);
  }

  /**
   * Generate GitHub Actions workflow step configuration
   * @param {Object} requirements - Parsed requirements
   * @returns {Object} GitHub Actions step configuration
   */
  generateGitHubActionsStep(requirements) {
    const config = this.buildConfiguration(requirements);
    const githubSecrets = this.extractGitHubSecrets(requirements.servers);

    return {
      name: 'Claude Code with Dynamic MCP',
      uses: 'anthropics/claude-code-action@beta',
      with: {
        anthropic_api_key: '${{ secrets.ANTHROPIC_API_KEY }}',
        github_token: '${{ secrets.GITHUB_TOKEN }}',
        mcp_config: JSON.stringify(config.mcp_config),
        allowed_tools: config.claude_config.allowed_tools.join(','),
        timeout: config.claude_config.timeout,
        comment_body: requirements.task_description
      },
      env: this.buildGitHubActionsEnv(githubSecrets)
    };
  }

  /**
   * Build GitHub Actions environment variables
   * @param {Array} githubSecrets - Array of required secrets
   * @returns {Object} Environment variables for GitHub Actions
   */
  buildGitHubActionsEnv(githubSecrets) {
    const env = {};

    githubSecrets.forEach(secret => {
      env[secret] = `\${{ secrets.${secret} }}`;
    });

    return env;
  }

  /**
   * Export configuration to file
   * @param {Object} config - Configuration object
   * @param {string} outputPath - Output file path
   */
  exportConfiguration(config, outputPath) {
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
    console.log(`Configuration exported to: ${outputPath}`);
  }
}

// CLI Interface
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.error('Usage: node mcp-config-builder.js <registry-path> <comment-text> [output-path]');
    console.error('   or: node mcp-config-builder.js <registry-path> --file <comment-file> [output-path]');
    process.exit(1);
  }

  const registryPath = args[0];
  let commentText = '';
  let outputPath = null;

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
    outputPath = args[3];
  } else {
    commentText = args[1];
    outputPath = args[2];
  }

  try {
    const builder = new MCPConfigBuilder(registryPath);
    const requirements = builder.parser.parseComment(commentText);
    const config = builder.buildConfiguration(requirements);

    if (outputPath) {
      builder.exportConfiguration(config, outputPath);
    } else {
      console.log(JSON.stringify(config, null, 2));
    }

    // GitHub Actions outputs
    if (process.env.GITHUB_ACTIONS) {
      const ghConfig = builder.generateGitHubActionsStep(requirements);
      console.log(`::set-output name=mcp_config::${JSON.stringify(config.mcp_config)}`);
      console.log(`::set-output name=allowed_tools::${config.claude_config.allowed_tools.join(',')}`);
      console.log(`::set-output name=timeout::${config.claude_config.timeout}`);
      console.log(`::set-output name=github_step::${JSON.stringify(ghConfig)}`);
    }
  } catch (error) {
    console.error('Error building configuration:', error.message);
    if (process.env.GITHUB_ACTIONS) {
      console.log(`::error::${error.message}`);
    }
    process.exit(1);
  }
}

module.exports = MCPConfigBuilder;