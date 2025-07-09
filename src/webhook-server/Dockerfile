# Multi-stage Dockerfile for webhook-server (Production Version)
# Build from project root context to access ../coding dependencies
FROM oven/bun:1-alpine AS base

# Install additional dependencies that might be needed
RUN apk add --no-cache git curl

WORKDIR /app

# Copy root package.json for shared dependencies and install first
COPY package.json ./package.json
RUN bun install --frozen-lockfile

# Copy webhook-server package.json and install its dependencies
COPY src/webhook-server/package.json ./webhook-server/package.json
WORKDIR /app/webhook-server
RUN bun install --frozen-lockfile

# Go back to root and copy required source directories
WORKDIR /app
COPY src/webhook-server ./webhook-server
COPY src/coding ./coding

# Build the application with access to all node_modules
WORKDIR /app/webhook-server
ENV NODE_PATH=/app/node_modules:/app/webhook-server/node_modules
RUN bun build index.ts --outdir=dist --target=node

# Production stage
FROM oven/bun:1-alpine AS production

WORKDIR /app

# Install runtime dependencies including kubectl and Claude Code CLI
RUN apk add --no-cache git curl nodejs npm bash && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    npm install -g @anthropic-ai/claude-code@1.0.43

# Copy package files and install runtime dependencies
COPY package.json ./package.json
COPY src/webhook-server/package.json ./webhook-server/package.json

# Install both root and webhook-server dependencies
RUN bun install --frozen-lockfile --production
WORKDIR /app/webhook-server
RUN bun install --frozen-lockfile --production

# Copy built application and required source files
WORKDIR /app
COPY --from=base /app/webhook-server/dist ./dist
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/webhook-server/node_modules ./webhook-server/node_modules
COPY --from=base /app/coding ./coding

# Set NODE_PATH to find all dependencies
ENV NODE_PATH=/app/node_modules:/app/webhook-server/node_modules

# Set SHELL environment variable for Claude CLI
ENV SHELL=/bin/bash

# Create non-root user
RUN addgroup -g 1001 -S webhook && \
    adduser -S webhook -u 1001 -G webhook

USER webhook

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-9000}/health || exit 1

# Expose port
EXPOSE 9000

# Start the application  
CMD ["bun", "run", "dist/index.js"]