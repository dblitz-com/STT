# Multi-stage Dockerfile for claude-runner
FROM oven/bun:1-alpine AS base

# Install system dependencies including Claude Code CLI
RUN apk add --no-cache \
    git \
    curl \
    bash \
    nodejs \
    npm

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /app

# Copy package files from root for shared dependencies
COPY package.json ./package.json

# Install dependencies
RUN bun install --frozen-lockfile

# Copy the entire coding directory to preserve imports
COPY src/coding ./src/coding/

# Ensure the entrypoints are executable
RUN chmod +x ./src/coding/entrypoints/claude-runner.ts

# Production stage  
FROM oven/bun:1-alpine AS production

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    git \
    curl \
    bash \
    nodejs \
    npm

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Copy package.json and install dependencies
COPY package.json ./package.json
RUN bun install --frozen-lockfile --production

# Copy application code
COPY --from=base /app/src ./src
COPY --from=base /app/node_modules ./node_modules

# Create non-root user
RUN addgroup -g 1001 -S claude && \
    adduser -S claude -u 1001 -G claude

# Create directories for configuration files
RUN mkdir -p /tmp && chown claude:claude /tmp

USER claude

# No health check needed for batch job

# No port exposure needed for batch job

# Default command - run as batch job
CMD ["bun", "run", "./src/coding/entrypoints/claude-runner.ts"]