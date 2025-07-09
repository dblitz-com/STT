/**
 * Initial Comment Creation for Agentic Coding System
 * 
 * Creates tracking comments when Claude Code begins processing.
 * Adapted from anthropics/claude-code-action.
 */

import type { Octokit } from "@octokit/rest";
import type { ParsedGitHubContext } from "../../context";

/**
 * Create initial tracking comment for Claude Code execution
 */
export async function createInitialComment(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<number> {
  const { repository, entityNumber } = context;

  if (!entityNumber) {
    throw new Error("Cannot create comment: no entity number found in context");
  }

  console.log(`Creating initial tracking comment for ${repository.full_name}#${entityNumber}`);

  const commentBody = createInitialCommentBody(context);

  try {
    const { data: comment } = await octokit.issues.createComment({
      owner: repository.owner,
      repo: repository.repo,
      issue_number: entityNumber,
      body: commentBody,
    });

    console.log(`✓ Created tracking comment with ID: ${comment.id}`);
    return comment.id;

  } catch (error) {
    console.error(`Failed to create initial comment: ${error instanceof Error ? error.message : String(error)}`);
    throw new Error(`Failed to create tracking comment: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Generate the body content for the initial comment
 */
function createInitialCommentBody(context: ParsedGitHubContext): string {
  const entityType = context.isPR ? "PR" : "issue";
  const timestamp = new Date().toISOString();

  return `## 🤖 Claude Code Processing Started

Hi! I'm Claude Code, and I've started processing this ${entityType}.

**Status:** 🔄 Initializing...  
**Started:** ${timestamp}  
**Triggered by:** @${context.actor}

I'll update this comment as I make progress. Here's what I'll be doing:

1. 🔍 Analyzing the ${entityType} description and requirements
2. 🌿 Creating a dedicated branch for my changes  
3. 💻 Writing and testing the necessary code
4. 📝 Documenting any changes made
5. 🔧 Running tests and ensuring quality

---

*This is an automated comment from our Agentic Coding System. I'm powered by Claude Code SDK and running on our Nomad cluster.*`;
}

/**
 * Create error comment when Claude Code fails to start
 */
export async function createErrorComment(
  octokit: Octokit,
  context: ParsedGitHubContext,
  error: string
): Promise<number> {
  const { repository, entityNumber } = context;

  if (!entityNumber) {
    throw new Error("Cannot create error comment: no entity number found in context");
  }

  console.log(`Creating error comment for ${repository.full_name}#${entityNumber}`);

  const commentBody = createErrorCommentBody(context, error);

  try {
    const { data: comment } = await octokit.issues.createComment({
      owner: repository.owner,
      repo: repository.repo,
      issue_number: entityNumber,
      body: commentBody,
    });

    console.log(`✓ Created error comment with ID: ${comment.id}`);
    return comment.id;

  } catch (createError) {
    console.error(`Failed to create error comment: ${createError instanceof Error ? createError.message : String(createError)}`);
    throw new Error(`Failed to create error comment: ${createError instanceof Error ? createError.message : String(createError)}`);
  }
}

/**
 * Generate error comment body
 */
function createErrorCommentBody(context: ParsedGitHubContext, error: string): string {
  const entityType = context.isPR ? "PR" : "issue";
  const timestamp = new Date().toISOString();

  return `## ❌ Claude Code Processing Failed

I encountered an error while trying to process this ${entityType}.

**Status:** ❌ Failed  
**Time:** ${timestamp}  
**Triggered by:** @${context.actor}

**Error details:**
\`\`\`
${error}
\`\`\`

**What you can try:**
- Check that I have the necessary permissions
- Verify the trigger phrase was correct (\`@claude\`, \`@claude-code\`, etc.)
- Make sure the repository configuration is correct
- Try triggering me again with a clearer description

---

*This is an automated comment from our Agentic Coding System. If this error persists, please check the system logs or contact support.*`;
}

/**
 * Create permission error comment
 */
export async function createPermissionErrorComment(
  octokit: Octokit,
  context: ParsedGitHubContext
): Promise<number> {
  return createErrorComment(
    octokit,
    context,
    `User @${context.actor} does not have sufficient permissions to trigger Claude Code on this repository. Write access is required.`
  );
}