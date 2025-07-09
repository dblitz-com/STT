#!/usr/bin/env bun

/**
 * Kubernetes-compatible replacement for @actions/core
 * 
 * Provides the same interface as @actions/core but uses console logging
 * instead of GitHub Actions workflow commands, making it suitable for
 * Kubernetes Job execution environments.
 */

export interface KubernetesCore {
  info: (message: string) => void;
  warning: (message: string) => void;
  debug: (message: string) => void;
  setFailed: (message: string) => void;
  setOutput: (name: string, value: string) => void;
  error: (message: string) => void;
  exportVariable: (name: string, value: string) => void;
  addPath: (inputPath: string) => void;
  getInput: (name: string, options?: { required?: boolean; trimWhitespace?: boolean }) => string;
  setSecret: (secret: string) => void;
  group: <T>(name: string, fn: () => Promise<T>) => Promise<T>;
  saveState: (name: string, value: string) => void;
  getState: (name: string) => string;
  getBooleanInput: (name: string, options?: { required?: boolean; trimWhitespace?: boolean }) => boolean;
  getMultilineInput: (name: string, options?: { required?: boolean; trimWhitespace?: boolean }) => string[];
  summary: {
    addRaw: (text: string) => any;
    write: () => Promise<any>;
  };
}

/**
 * Create a Kubernetes-compatible core instance
 */
export function createKubernetesCore(): KubernetesCore {
  return {
    info: (message: string) => console.log(`INFO: ${message}`),
    warning: (message: string) => console.warn(`WARNING: ${message}`),
    debug: (message: string) => console.log(`DEBUG: ${message}`),
    setFailed: (message: string) => console.error(`FAILED: ${message}`),
    setOutput: (name: string, value: string) => console.log(`OUTPUT: ${name}=${value}`),
    error: (message: string) => console.error(`ERROR: ${message}`),
    exportVariable: (name: string, value: string) => {
      process.env[name] = value;
      console.log(`EXPORT: ${name}=${value}`);
    },
    addPath: (inputPath: string) => {
      const currentPath = process.env.PATH || "";
      process.env.PATH = `${inputPath}:${currentPath}`;
      console.log(`ADD_PATH: ${inputPath}`);
    },
    getInput: (name: string, options = {}) => {
      const value = process.env[`INPUT_${name.toUpperCase()}`] || "";
      if (options.required && !value) {
        throw new Error(`Input required and not supplied: ${name}`);
      }
      return options.trimWhitespace !== false ? value.trim() : value;
    },
    setSecret: (secret: string) => {
      console.log(`SECRET: [REDACTED]`);
    },
    group: async <T>(name: string, fn: () => Promise<T>): Promise<T> => {
      console.log(`GROUP: ${name}`);
      try {
        const result = await fn();
        console.log(`GROUP_END: ${name}`);
        return result;
      } catch (error) {
        console.error(`GROUP_ERROR: ${name} - ${error}`);
        throw error;
      }
    },
    saveState: (name: string, value: string) => {
      process.env[`STATE_${name}`] = value;
      console.log(`SAVE_STATE: ${name}=${value}`);
    },
    getState: (name: string) => {
      return process.env[`STATE_${name}`] || "";
    },
    getBooleanInput: (name: string, options = {}) => {
      const value = process.env[`INPUT_${name.toUpperCase()}`] || "";
      if (options.required && !value) {
        throw new Error(`Input required and not supplied: ${name}`);
      }
      const trimmed = options.trimWhitespace !== false ? value.trim() : value;
      return trimmed.toLowerCase() === 'true';
    },
    getMultilineInput: (name: string, options = {}) => {
      const value = process.env[`INPUT_${name.toUpperCase()}`] || "";
      if (options.required && !value) {
        throw new Error(`Input required and not supplied: ${name}`);
      }
      const trimmed = options.trimWhitespace !== false ? value.trim() : value;
      return trimmed ? trimmed.split('\n') : [];
    },
    summary: {
      addRaw: (text: string) => {
        console.log(`SUMMARY: ${text}`);
        return {}; // Return empty object to match @actions/core interface
      },
      write: async () => {
        console.log(`SUMMARY_WRITE: Summary written`);
        return {}; // Return empty object to match @actions/core interface
      },
    },
  };
}

/**
 * Default export - a ready-to-use core instance
 */
export const core = createKubernetesCore();

/**
 * For backward compatibility with direct imports
 */
export const {
  info,
  warning,
  debug,
  setFailed,
  setOutput,
  error,
  exportVariable,
  addPath,
  getInput,
  setSecret,
  group,
  saveState,
  getState,
  getBooleanInput,
  getMultilineInput,
  summary,
} = core;