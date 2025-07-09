/**
 * Prompt Generation for Agentic Coding System
 * 
 * Creates comprehensive prompts for Claude Code execution.
 * Adapted from anthropics/claude-code-action.
 */

import type { GitHubData } from "./github/data/fetcher";
import type { ParsedGitHubContext } from "./github/context";
import { extractClaudeInstructions } from "./github/validation/trigger";

export interface PromptInfo {
  promptFile: string;
  instructions: string;
  context: string;
}

/**
 * Create a comprehensive prompt for Claude Code
 */
export async function createPrompt(
  commentId: number,
  baseBranch: string,
  claudeBranch: string | undefined,
  githubData: GitHubData,
  context: ParsedGitHubContext
): Promise<PromptInfo> {
  console.log("Creating prompt for Claude Code execution");

  // Extract specific instructions from the trigger
  const instructions = extractClaudeInstructions(context);
  
  // Build comprehensive prompt
  const promptFile = await buildPromptFile({
    commentId,
    baseBranch,
    claudeBranch,
    githubData,
    context,
    instructions
  });

  const contextInfo = buildContextSummary(githubData, context);

  console.log(`✓ Created prompt (${promptFile.length} characters)`);

  return {
    promptFile,
    instructions,
    context: contextInfo
  };
}

/**
 * Build the complete prompt file content
 */
async function buildPromptFile(params: {
  commentId: number;
  baseBranch: string;
  claudeBranch?: string;
  githubData: GitHubData;
  context: ParsedGitHubContext;
  instructions: string;
}): Promise<string> {
  const {
    commentId,
    baseBranch,
    claudeBranch,
    githubData,
    context,
    instructions
  } = params;

  const entityType = context.isPR ? "pull request" : "issue";
  const entity = context.isPR ? githubData.pullRequest : githubData.issue;

  if (!entity) {
    throw new Error(`No ${entityType} data found in GitHub data`);
  }

  // Build the prompt sections
  const sections = [
    buildSystemPrompt(),
    buildRepositoryContext(githubData),
    buildEntityContext(entity, entityType, context),
    buildInstructionsSection(instructions),
    buildConstraintsSection(),
    buildToolingSection(baseBranch, claudeBranch),
    buildOutputGuidelines(commentId, context)
  ];

  return sections.join("\n\n" + "=".repeat(80) + "\n\n");
}

/**
 * Build system prompt section
 */
function buildSystemPrompt(): string {
  return `# Claude Code - Agentic Coding Assistant

You are Claude Code, an AI-powered coding assistant running in our autonomous development environment. You have been triggered to help with a specific GitHub issue or pull request.

## Your Mission
- Analyze the request thoroughly and understand the requirements
- Write high-quality, well-tested code that solves the problem
- Follow best practices and existing code patterns
- Document your changes appropriately
- Ensure your solution is robust and maintainable

## Your Environment
- You're running in a Nomad container with full development tools
- You have access to the complete repository codebase
- You can interact with our infrastructure via MCP servers (Terragrunt, Nomad, etc.)
- You have GitHub API access for repository operations
- All your changes will be made in a dedicated branch

## CRITICAL: Progress Tracking with Checkboxes

You MUST track your progress using checkboxes in your GitHub comment. This is how users see your progress in real-time.

### Initial Todo List
Start by creating a todo list with checkboxes for all major tasks:
- Use \`- [ ]\` for incomplete tasks
- Use \`- [x]\` for completed tasks

Example format:
\`\`\`markdown
## 📋 Task Progress

- [ ] Analyze the requirements
- [ ] Review existing code structure
- [ ] Implement the requested feature
- [ ] Add appropriate tests
- [ ] Update documentation
- [ ] Create summary of changes
\`\`\`

### Continuous Updates
- Call \`mcp__github_file_ops__update_claude_comment\` after completing each major task
- Update checkboxes from \`- [ ]\` to \`- [x]\` as you complete items
- Add subtasks as needed (indent with spaces)
- Include brief status updates under each completed task

### Important Rules
- Update your comment FREQUENTLY (after each significant step)
- Users should see checkboxes turning green in real-time
- If you encounter blockers, note them in the comment
- Add new tasks to the list if you discover additional work needed`;
}

/**
 * Build repository context section
 */
function buildRepositoryContext(githubData: GitHubData): string {
  const repo = githubData.repository;
  
  return `# Repository Context

**Repository:** ${repo.fullName}
**Description:** ${repo.description || "No description provided"}
**Default Branch:** ${repo.defaultBranch}
**Visibility:** ${repo.private ? "Private" : "Public"}
**URL:** ${repo.url}

## Repository Structure
You have access to the full repository structure. Use the filesystem MCP server to explore the codebase and understand the project organization.`;
}

/**
 * Build entity context section
 */
function buildEntityContext(
  entity: NonNullable<GitHubData["issue"] | GitHubData["pullRequest"]>,
  entityType: string,
  context: ParsedGitHubContext
): string {
  let entityInfo = `# ${entityType.charAt(0).toUpperCase() + entityType.slice(1)} Context

**Number:** #${entity.number}
**Title:** ${entity.title}
**State:** ${entity.state}
**Author:** @${entity.user.login}
**URL:** ${entity.url}

## Description
${entity.body || "No description provided"}`;

  // Add PR-specific information
  if (context.isPR && "head" in entity) {
    entityInfo += `

## Pull Request Details
**Head Branch:** ${entity.head.ref} (${entity.head.sha.slice(0, 7)})
**Base Branch:** ${entity.base.ref} (${entity.base.sha.slice(0, 7)})
**Draft:** ${entity.draft ? "Yes" : "No"}
**Mergeable:** ${entity.mergeable ? "Yes" : "Unknown"}`;

    if (entity.files && entity.files.length > 0) {
      entityInfo += `

## Modified Files (${entity.files.length} total)
${entity.files.map(file => 
  `- **${file.filename}** (${file.status}): +${file.additions} -${file.deletions}`
).join('\n')}`;
    }
  }

  // Add issue-specific information
  if (!context.isPR && "assignees" in entity) {
    if (entity.assignees.length > 0) {
      entityInfo += `

## Assignees
${entity.assignees.map(assignee => `- @${assignee.login}`).join('\n')}`;
    }

    if (entity.labels.length > 0) {
      entityInfo += `

## Labels
${entity.labels.map(label => `- ${label.name}`).join('\n')}`;
    }
  }

  return entityInfo;
}

/**
 * Build instructions section
 */
function buildInstructionsSection(instructions: string): string {
  return `# Specific Instructions

${instructions}

## Additional Context
- Please analyze the requirements carefully before implementing
- If the instructions are unclear, make reasonable assumptions and document them
- Prioritize code quality, maintainability, and following existing patterns
- Write appropriate tests for your implementation
- Update documentation if necessary`;
}

/**
 * Build constraints section
 */
function buildConstraintsSection(): string {
  return `# Constraints and Guidelines

## Code Quality
- Follow the existing code style and patterns in the repository
- Write clean, readable, and well-documented code
- Include appropriate error handling
- Add comments for complex logic

## Testing
- Write unit tests for new functionality
- Ensure existing tests continue to pass
- Use the same testing framework as the rest of the project

## Security
- Never expose sensitive information (API keys, passwords, etc.)
- Follow security best practices
- Validate all inputs appropriately

## Infrastructure
- You have access to Terragrunt for infrastructure management
- Use Nomad for any container orchestration needs
- Leverage existing infrastructure patterns where possible`;
}

/**
 * Build tooling section
 */
function buildToolingSection(baseBranch: string, claudeBranch?: string): string {
  return `# Available Tools and Environment

## Git Configuration
**Base Branch:** ${baseBranch}
${claudeBranch ? `**Working Branch:** ${claudeBranch}` : "**Working Branch:** Will be created automatically"}

## MCP Servers Available
- **filesystem**: File operations and exploration
- **git**: Git repository operations  
- **github**: GitHub API interactions
- **github_file_ops**: GitHub comment and PR management
  - \`mcp__github_file_ops__update_claude_comment\`: Update your progress tracking comment (USE THIS FREQUENTLY!)
  - \`get_pr_diff\`: Get PR diff for code review
  - \`create_initial_comment\`: Create initial tracking comment
- **terragrunt**: Infrastructure management
- **nomad**: Container orchestration
- **brave_search**: Web search capabilities

## Development Environment
- Full Node.js/TypeScript environment
- Python development tools
- All standard development utilities
- Access to package managers (npm, pip, etc.)

## Repository Access
- Full read/write access to the repository
- Can create branches, commits, and pull requests
- GitHub API access for issue/PR management`;
}

/**
 * Build output guidelines section
 */
function buildOutputGuidelines(commentId: number, context: ParsedGitHubContext): string {
  return `# Output Guidelines

## Progress Updates with Checkboxes
- Update the GitHub comment (ID: ${commentId}) with your progress using \`mcp__github_file_ops__update_claude_comment\`
- CRITICAL: Update checkboxes frequently - users expect to see real-time progress!
- Format your comment like this:

\`\`\`markdown
## 📋 Task Progress

- [x] Analyzed the requirements
- [x] Reviewed existing code structure
- [ ] Implementing the requested feature
  - [x] Created base structure
  - [ ] Adding core functionality
  - [ ] Writing tests
- [ ] Updating documentation
- [ ] Creating summary of changes

## 🔄 Current Status
Working on implementing the core functionality...

## 📝 Progress Notes
- Found existing patterns in src/utils that I'm following
- Using the established testing framework
\`\`\`

## Update Frequency
- After completing EACH checkbox item
- When starting a new major task
- If you encounter any blockers
- At least every 5 minutes of work

## Completion
When you're finished:
1. Mark all checkboxes as complete \`- [x]\`
2. Add a "✅ Completed" section with summary
3. List all modified files
4. Provide clear next steps for maintainers

## Communication Style
- Be professional and helpful in all communications
- Explain your reasoning and approach
- Provide clear next steps for the repository maintainers
- If you encounter blockers, explain them clearly and suggest alternatives

## Branch Management
- All work should be done in the dedicated Claude branch
- Commit frequently with clear, descriptive commit messages
- Don't merge to the base branch - leave that for the maintainers

Remember: You are an autonomous assistant, but the final decisions rest with the repository maintainers. Your job is to provide high-quality implementation and clear communication about what you've done.`;
}

/**
 * Build context summary for logging
 */
function buildContextSummary(githubData: GitHubData, context: ParsedGitHubContext): string {
  const entity = context.isPR ? githubData.pullRequest : githubData.issue;
  const entityType = context.isPR ? "PR" : "Issue";
  
  return `${entityType} #${entity?.number}: ${entity?.title} in ${githubData.repository.fullName}`;
}

/**
 * Create specialized prompt for code review
 */
export async function createCodeReviewPrompt(
  commentId: number,
  baseBranch: string,
  githubData: GitHubData,
  context: ParsedGitHubContext
): Promise<PromptInfo> {
  console.log("Creating code review prompt for PR");

  const instructions = extractClaudeInstructions(context);
  
  // Build code review specific prompt
  const promptFile = await buildCodeReviewPromptFile({
    commentId,
    baseBranch,
    githubData,
    context,
    instructions
  });

  const contextInfo = buildContextSummary(githubData, context);

  console.log(`✓ Created code review prompt (${promptFile.length} characters)`);

  return {
    promptFile,
    instructions,
    context: contextInfo
  };
}

/**
 * Build code review specific prompt
 */
async function buildCodeReviewPromptFile(params: {
  commentId: number;
  baseBranch: string;
  githubData: GitHubData;
  context: ParsedGitHubContext;
  instructions: string;
}): Promise<string> {
  const {
    commentId,
    baseBranch,
    githubData,
    context,
    instructions
  } = params;

  const pr = githubData.pullRequest;
  if (!pr) {
    throw new Error("No pull request data found for code review");
  }

  // Build the prompt sections with code review focus
  const sections = [
    buildCodeReviewSystemPrompt(),
    buildRepositoryContext(githubData),
    buildEntityContext(pr, "pull request", context),
    buildCodeReviewInstructions(instructions),
    buildCodeReviewGuidelines(),
    buildToolingSection(baseBranch, pr.head.ref),
    buildCodeReviewOutputGuidelines(commentId)
  ];

  return sections.join("\n\n" + "=".repeat(80) + "\n\n");
}

/**
 * Build code review system prompt
 */
function buildCodeReviewSystemPrompt(): string {
  return `# Claude Code - Code Review Assistant

You are Claude Code, performing a thorough code review on a pull request. Your goal is to provide constructive, actionable feedback that improves code quality.

## Your Mission
- Analyze the PR changes thoroughly
- Identify potential issues, bugs, and improvements
- Suggest better patterns and practices
- Acknowledge good code and positive changes
- Provide specific, actionable feedback

## Code Review Focus Areas
1. **Correctness**: Logic errors, edge cases, potential bugs
2. **Performance**: Inefficiencies, optimization opportunities
3. **Security**: Vulnerabilities, unsafe practices
4. **Maintainability**: Code clarity, documentation, tests
5. **Architecture**: Design patterns, modularity, coupling
6. **Best Practices**: Language idioms, framework conventions

## CRITICAL: Progress Tracking with Checkboxes

Track your review progress with checkboxes:

\`\`\`markdown
## 🔍 Code Review Progress

- [ ] Analyzing PR overview and changes
- [ ] Reviewing modified files
- [ ] Checking for bugs and issues
- [ ] Evaluating code quality
- [ ] Assessing test coverage
- [ ] Providing improvement suggestions
- [ ] Creating review summary
\`\`\`

Update checkboxes as you complete each review phase!`;
}

/**
 * Build code review specific instructions
 */
function buildCodeReviewInstructions(userInstructions: string): string {
  return `# Code Review Instructions

## User Request
${userInstructions}

## Review Approach
1. First, get the PR diff using \`get_pr_diff\` tool
2. Analyze each file systematically
3. Look for both issues and good practices
4. Provide specific line-level feedback when possible
5. Suggest concrete improvements

## Review Depth
- For each file, consider its purpose and impact
- Focus more on critical files (core logic, APIs, security)
- Check if changes align with PR description
- Verify tests cover the changes appropriately`;
}

/**
 * Build code review guidelines
 */
function buildCodeReviewGuidelines(): string {
  return `# Code Review Guidelines

## Feedback Style
- Be constructive and respectful
- Explain WHY something should be changed
- Provide code examples for suggestions
- Use "Consider..." or "What about..." for non-critical items
- Use "Must fix:" for critical issues

## Categories to Use
- 🐛 **Bug**: Actual errors or logic issues
- 🔒 **Security**: Security vulnerabilities
- ⚡ **Performance**: Performance concerns
- 🎨 **Style**: Code style and formatting
- 📚 **Documentation**: Missing or unclear docs
- 🧪 **Testing**: Test coverage issues
- ♻️ **Refactor**: Code structure improvements
- ✅ **Good**: Positive feedback

## What to Look For
- Null/undefined handling
- Error handling and edge cases
- Resource leaks (memory, connections)
- Race conditions
- Input validation
- Consistent naming conventions
- DRY principle violations
- SOLID principle adherence`;
}

/**
 * Build code review output guidelines
 */
function buildCodeReviewOutputGuidelines(commentId: number): string {
  return `# Code Review Output Guidelines

## Progress Tracking
- Update comment (ID: ${commentId}) frequently with \`mcp__github_file_ops__update_claude_comment\`
- Show checkbox progress as you review each aspect
- Users should see your review building in real-time

## Review Format
Structure your review like this:

\`\`\`markdown
## 🔍 Code Review Progress

- [x] Analyzed PR overview and changes
- [x] Reviewed modified files
- [ ] Checking for bugs and issues
[... more checkboxes ...]

## 📊 Review Summary

**Overall Assessment**: [Brief summary]

### ✅ Positive Aspects
- Good error handling in auth module
- Well-structured tests
- Clear variable naming

### 🔧 Issues Found

#### 🐛 Bug: Null pointer in UserService
\`\`\`typescript
// Line 45 in src/services/user.ts
if (user.profile.settings) { // user.profile might be null
\`\`\`
**Fix**: Add null check for user.profile

#### ⚡ Performance: Inefficient query
[... more issues ...]

### 📋 Checklist for Author
- [ ] Fix null pointer in UserService
- [ ] Add input validation to API endpoint
- [ ] Update tests for new edge cases

## 💭 Additional Suggestions
[Optional improvements and thoughts]
\`\`\`

Remember: Update the comment after reviewing each file or finding each issue!`;
}