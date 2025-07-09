#!/usr/bin/env node

/**
 * Example FluxCD MCP Server
 * This is a reference implementation showing how to create an MCP server
 * that provides FluxCD GitOps tools for Claude Code Actions
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

class FluxMCPServer {
  constructor() {
    this.tools = {
      flux_status: {
        name: 'flux_status',
        description: 'Get FluxCD system status',
        inputSchema: {
          type: 'object',
          properties: {
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          }
        }
      },
      flux_logs: {
        name: 'flux_logs',
        description: 'Get FluxCD controller logs',
        inputSchema: {
          type: 'object',
          properties: {
            controller: {
              type: 'string',
              description: 'Controller name (source-controller, kustomize-controller, etc.)'
            },
            lines: {
              type: 'number',
              description: 'Number of log lines to retrieve (default: 100)'
            },
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          },
          required: ['controller']
        }
      },
      flux_reconcile: {
        name: 'flux_reconcile',
        description: 'Force reconciliation of FluxCD resources',
        inputSchema: {
          type: 'object',
          properties: {
            kind: {
              type: 'string',
              description: 'Resource kind (gitrepository, kustomization, helmrelease)',
              enum: ['gitrepository', 'kustomization', 'helmrelease']
            },
            name: {
              type: 'string',
              description: 'Resource name'
            },
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          },
          required: ['kind', 'name']
        }
      },
      flux_get_sources: {
        name: 'flux_get_sources',
        description: 'Get FluxCD source resources (GitRepository, HelmRepository, etc.)',
        inputSchema: {
          type: 'object',
          properties: {
            kind: {
              type: 'string',
              description: 'Source kind (gitrepository, helmrepository, bucket)'
            },
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          }
        }
      },
      flux_get_kustomizations: {
        name: 'flux_get_kustomizations',
        description: 'Get FluxCD Kustomization resources',
        inputSchema: {
          type: 'object',
          properties: {
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          }
        }
      },
      flux_suspend: {
        name: 'flux_suspend',
        description: 'Suspend FluxCD resource reconciliation',
        inputSchema: {
          type: 'object',
          properties: {
            kind: {
              type: 'string',
              description: 'Resource kind',
              enum: ['gitrepository', 'kustomization', 'helmrelease']
            },
            name: {
              type: 'string',
              description: 'Resource name'
            },
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          },
          required: ['kind', 'name']
        }
      },
      flux_resume: {
        name: 'flux_resume',
        description: 'Resume FluxCD resource reconciliation',
        inputSchema: {
          type: 'object',
          properties: {
            kind: {
              type: 'string',
              description: 'Resource kind',
              enum: ['gitrepository', 'kustomization', 'helmrelease']
            },
            name: {
              type: 'string',
              description: 'Resource name'
            },
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          },
          required: ['kind', 'name']
        }
      },
      flux_get_alerts: {
        name: 'flux_get_alerts',
        description: 'Get FluxCD alerts and notifications',
        inputSchema: {
          type: 'object',
          properties: {
            namespace: {
              type: 'string',
              description: 'Kubernetes namespace (default: flux-system)'
            }
          }
        }
      },
      flux_check_health: {
        name: 'flux_check_health',
        description: 'Check overall FluxCD system health',
        inputSchema: {
          type: 'object',
          properties: {
            detailed: {
              type: 'boolean',
              description: 'Include detailed health information'
            }
          }
        }
      }
    };

    this.kubeconfig = process.env.KUBECONFIG;
    this.fluxNamespace = process.env.FLUX_NAMESPACE || 'flux-system';
    
    if (!this.kubeconfig) {
      throw new Error('KUBECONFIG environment variable is required');
    }
  }

  async executeCommand(command, args) {
    return new Promise((resolve, reject) => {
      const process = spawn(command, args, {
        env: { ...process.env, KUBECONFIG: this.kubeconfig },
        stdio: 'pipe'
      });

      let stdout = '';
      let stderr = '';

      process.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      process.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      process.on('close', (code) => {
        if (code === 0) {
          resolve(stdout);
        } else {
          reject(new Error(`Command failed with code ${code}: ${stderr}`));
        }
      });
    });
  }

  async flux_status(args) {
    const namespace = args.namespace || this.fluxNamespace;
    
    try {
      const output = await this.executeCommand('flux', ['get', 'all', '-n', namespace]);
      
      return {
        content: [{
          type: 'text',
          text: `FluxCD Status (namespace: ${namespace}):\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error getting FluxCD status: ${error.message}`
        }]
      };
    }
  }

  async flux_logs(args) {
    const { controller, lines = 100, namespace = this.fluxNamespace } = args;
    
    try {
      const output = await this.executeCommand('kubectl', [
        'logs',
        '-n', namespace,
        `deployment/${controller}`,
        '--tail', lines.toString()
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `Logs for ${controller} (last ${lines} lines):\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error getting logs for ${controller}: ${error.message}`
        }]
      };
    }
  }

  async flux_reconcile(args) {
    const { kind, name, namespace = this.fluxNamespace } = args;
    
    try {
      const output = await this.executeCommand('flux', [
        'reconcile',
        kind,
        name,
        '-n', namespace
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `Reconciliation triggered for ${kind}/${name}:\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error reconciling ${kind}/${name}: ${error.message}`
        }]
      };
    }
  }

  async flux_get_sources(args) {
    const { kind, namespace = this.fluxNamespace } = args;
    const resourceType = kind || 'sources';
    
    try {
      const output = await this.executeCommand('flux', [
        'get', resourceType, '-n', namespace, '--output', 'wide'
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `FluxCD Sources (${resourceType}):\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error getting FluxCD sources: ${error.message}`
        }]
      };
    }
  }

  async flux_get_kustomizations(args) {
    const namespace = args.namespace || this.fluxNamespace;
    
    try {
      const output = await this.executeCommand('flux', [
        'get', 'kustomizations', '-n', namespace, '--output', 'wide'
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `FluxCD Kustomizations:\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error getting Kustomizations: ${error.message}`
        }]
      };
    }
  }

  async flux_suspend(args) {
    const { kind, name, namespace = this.fluxNamespace } = args;
    
    try {
      const output = await this.executeCommand('flux', [
        'suspend', kind, name, '-n', namespace
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `Suspended ${kind}/${name}:\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error suspending ${kind}/${name}: ${error.message}`
        }]
      };
    }
  }

  async flux_resume(args) {
    const { kind, name, namespace = this.fluxNamespace } = args;
    
    try {
      const output = await this.executeCommand('flux', [
        'resume', kind, name, '-n', namespace
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `Resumed ${kind}/${name}:\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error resuming ${kind}/${name}: ${error.message}`
        }]
      };
    }
  }

  async flux_get_alerts(args) {
    const namespace = args.namespace || this.fluxNamespace;
    
    try {
      const output = await this.executeCommand('flux', [
        'get', 'alerts', '-n', namespace
      ]);
      
      return {
        content: [{
          type: 'text',
          text: `FluxCD Alerts:\n\n${output}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error getting alerts: ${error.message}`
        }]
      };
    }
  }

  async flux_check_health(args) {
    const { detailed = false } = args;
    
    try {
      // Get overall system status
      const systemStatus = await this.executeCommand('flux', ['check']);
      
      let output = `FluxCD System Health Check:\n\n${systemStatus}`;
      
      if (detailed) {
        // Get detailed status of all resources
        const allResources = await this.executeCommand('flux', [
          'get', 'all', '-n', this.fluxNamespace
        ]);
        
        output += `\n\nDetailed Resource Status:\n${allResources}`;
        
        // Check controller pods
        const pods = await this.executeCommand('kubectl', [
          'get', 'pods', '-n', this.fluxNamespace, '-l', 'app.kubernetes.io/part-of=flux'
        ]);
        
        output += `\n\nController Pods:\n${pods}`;
      }
      
      return {
        content: [{
          type: 'text',
          text: output
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error checking FluxCD health: ${error.message}`
        }]
      };
    }
  }

  async handleToolCall(toolName, args) {
    if (!this.tools[toolName]) {
      throw new Error(`Unknown tool: ${toolName}`);
    }

    return await this[toolName](args);
  }

  listTools() {
    return Object.values(this.tools);
  }

  // MCP Protocol implementation
  async initialize() {
    return {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: {}
      },
      serverInfo: {
        name: 'flux-mcp-server',
        version: '1.0.0',
        description: 'FluxCD GitOps MCP Server for Claude Code Actions'
      }
    };
  }

  async processMessage(message) {
    switch (message.method) {
      case 'tools/list':
        return { tools: this.listTools() };
      
      case 'tools/call':
        const { name, arguments: args } = message.params;
        return await this.handleToolCall(name, args);
      
      default:
        throw new Error(`Unknown method: ${message.method}`);
    }
  }
}

// CLI interface for testing
if (require.main === module) {
  const server = new FluxMCPServer();
  
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error('Usage: node flux-mcp-server.js <tool-name> [args...]');
    console.error('Available tools:');
    server.listTools().forEach(tool => {
      console.error(`  - ${tool.name}: ${tool.description}`);
    });
    process.exit(1);
  }

  const toolName = args[0];
  const toolArgs = args.length > 1 ? JSON.parse(args[1]) : {};

  server.handleToolCall(toolName, toolArgs)
    .then(result => {
      console.log(JSON.stringify(result, null, 2));
    })
    .catch(error => {
      console.error('Error:', error.message);
      process.exit(1);
    });
}

module.exports = FluxMCPServer;