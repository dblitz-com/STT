#!/usr/bin/env node
// Local Git Operations MCP Server - Exact copy of github-file-ops-server.ts but for local git
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFile } from "fs/promises";
import { join } from "path";
import { $ } from "bun";

// Get repository information from environment variables
const REPO_DIR = process.env.REPO_DIR || process.cwd();
const BRANCH_NAME = process.env.BRANCH_NAME || "main";

const server = new McpServer({
  name: "Local Git Operations Server",
  version: "0.0.1",
});

// Commit files tool - exact same interface as github-file-ops-server.ts
server.tool(
  "commit_files",
  "Commit one or more files to a repository in a single commit (this will commit them atomically in the local repository)",
  {
    files: z
      .array(z.string())
      .describe(
        'Array of file paths relative to repository root (e.g. ["src/main.js", "README.md"]). All files must exist locally.',
      ),
    message: z.string().describe("Commit message"),
  },
  async ({ files, message }) => {
    try {
      const processedFiles = files.map((filePath) => {
        if (filePath.startsWith("/")) {
          return filePath.slice(1);
        }
        return filePath;
      });

      // Change to repository directory
      process.chdir(REPO_DIR);

      // 1. Get the current commit SHA (equivalent to getting branch reference)
      const currentSha = await $`git rev-parse HEAD`.text();
      const baseSha = currentSha.trim();

      // 2. Verify all files exist locally
      for (const filePath of processedFiles) {
        const fullPath = join(REPO_DIR, filePath);
        try {
          await readFile(fullPath);
        } catch (error) {
          throw new Error(`File not found: ${filePath}`);
        }
      }

      // 3. Stage all the files (equivalent to creating tree entries)
      for (const filePath of processedFiles) {
        await $`git add ${filePath}`;
      }

      // 4. Set git identity (like GitHub Actions bot)
      await $`git config user.name "claude-local[bot]"`;
      await $`git config user.email "claude-local[bot]@users.noreply.local"`;

      // 5. Create the commit (equivalent to GitHub API commit creation)
      await $`git commit -m ${message}`;

      // 6. Get the new commit SHA
      const newCommitSha = await $`git rev-parse HEAD`.text();
      const newSha = newCommitSha.trim();

      // 7. Get commit details for response
      const commitDetails = await $`git show --format="%H|%s|%an|%ad" --no-patch ${newSha}`.text();
      const [sha, commitMessage, author, date] = commitDetails.trim().split('|');

      // 8. Get tree SHA (equivalent to GitHub tree)
      const treeSha = await $`git rev-parse ${newSha}^{tree}`.text();

      const simplifiedResult = {
        commit: {
          sha: sha,
          message: commitMessage,
          author: author,
          date: date,
        },
        files: processedFiles.map((path) => ({ path })),
        tree: {
          sha: treeSha.trim(),
        },
      };

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(simplifiedResult, null, 2),
          },
        ],
      };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text",
            text: `Error: ${errorMessage}`,
          },
        ],
        error: errorMessage,
        isError: true,
      };
    }
  },
);

// Delete files tool - exact same interface as github-file-ops-server.ts
server.tool(
  "delete_files",
  "Delete one or more files from a repository in a single commit",
  {
    paths: z
      .array(z.string())
      .describe(
        'Array of file paths to delete relative to repository root (e.g. ["src/old-file.js", "docs/deprecated.md"])',
      ),
    message: z.string().describe("Commit message"),
  },
  async ({ paths, message }) => {
    try {
      // Convert absolute paths to relative if they match CWD
      const cwd = process.cwd();
      const processedPaths = paths.map((filePath) => {
        if (filePath.startsWith("/")) {
          if (filePath.startsWith(cwd)) {
            // Strip CWD from absolute path
            return filePath.slice(cwd.length + 1);
          } else {
            throw new Error(
              `Path '${filePath}' must be relative to repository root or within current working directory`,
            );
          }
        }
        return filePath;
      });

      // Change to repository directory
      process.chdir(REPO_DIR);

      // 1. Get the current commit SHA
      const currentSha = await $`git rev-parse HEAD`.text();
      const baseSha = currentSha.trim();

      // 2. Remove the files from git
      for (const filePath of processedPaths) {
        await $`git rm ${filePath}`;
      }

      // 3. Set git identity (like GitHub Actions bot)
      await $`git config user.name "claude-local[bot]"`;
      await $`git config user.email "claude-local[bot]@users.noreply.local"`;

      // 4. Create the commit
      await $`git commit -m ${message}`;

      // 5. Get the new commit SHA
      const newCommitSha = await $`git rev-parse HEAD`.text();
      const newSha = newCommitSha.trim();

      // 6. Get commit details for response
      const commitDetails = await $`git show --format="%H|%s|%an|%ad" --no-patch ${newSha}`.text();
      const [sha, commitMessage, author, date] = commitDetails.trim().split('|');

      // 7. Get tree SHA
      const treeSha = await $`git rev-parse ${newSha}^{tree}`.text();

      const simplifiedResult = {
        commit: {
          sha: sha,
          message: commitMessage,
          author: author,
          date: date,
        },
        deletedFiles: processedPaths.map((path) => ({ path })),
        tree: {
          sha: treeSha.trim(),
        },
      };

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(simplifiedResult, null, 2),
          },
        ],
      };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text",
            text: `Error: ${errorMessage}`,
          },
        ],
        error: errorMessage,
        isError: true,
      };
    }
  },
);

async function runServer() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  process.on("exit", () => {
    server.close();
  });
}

runServer().catch(console.error);