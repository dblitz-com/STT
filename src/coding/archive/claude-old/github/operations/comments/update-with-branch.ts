/**
 * Comment Update Operations for Agentic Coding System
 * 
 * Updates tracking comments with progress information.
 * Adapted from anthropics/claude-code-action.
 */

import type { Octokit } from "@octokit/rest";
import type { ParsedGitHubContext } from "../../context";
import type { OctokitInstance } from "../../api/client";

/**
 * Update tracking comment with branch information
 */
export async function updateTrackingComment(
  octokit: OctokitInstance,
  context: ParsedGitHubContext,
  commentId: number,
  branchName: string
): Promise<void> {
  const { repository } = context;

  console.log(`Updating tracking comment ${commentId} with branch: ${branchName}`);

  const updatedBody = createBranchUpdateCommentBody(context, branchName);

  try {
    await octokit.rest.issues.updateComment({
      owner: repository.owner,
      repo: repository.repo,
      comment_id: commentId,
      body: updatedBody,
    });

    console.log(`✓ Updated tracking comment with branch information`);

  } catch (error) {
    console.error(`Failed to update tracking comment: ${error instanceof Error ? error.message : String(error)}`);
    // Don't throw here - comment update failures shouldn't stop the process
  }
}

/**
 * Update tracking comment with job status
 */
export async function updateCommentWithJobStatus(
  octokit: OctokitInstance,
  context: ParsedGitHubContext,
  commentId: number,
  jobId: string,
  status: "running" | "completed" | "failed"
): Promise<void> {
  const { repository } = context;

  console.log(`Updating tracking comment ${commentId} with job status: ${status}`);

  const updatedBody = createJobStatusCommentBody(context, jobId, status);

  try {
    await octokit.rest.issues.updateComment({
      owner: repository.owner,
      repo: repository.repo,
      comment_id: commentId,
      body: updatedBody,
    });

    console.log(`✓ Updated tracking comment with job status`);

  } catch (error) {
    console.error(`Failed to update tracking comment: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Update tracking comment with completion information
 */
export async function updateCommentWithCompletion(
  octokit: OctokitInstance,
  context: ParsedGitHubContext,
  commentId: number,
  result: {
    branchName?: string;
    pullRequestNumber?: number;
    summary: string;
    filesChanged: string[];
  }
): Promise<void> {
  const { repository } = context;

  console.log(`Updating tracking comment ${commentId} with completion info`);

  const updatedBody = createCompletionCommentBody(context, result);

  try {
    await octokit.rest.issues.updateComment({
      owner: repository.owner,
      repo: repository.repo,
      comment_id: commentId,
      body: updatedBody,
    });

    console.log(`✓ Updated tracking comment with completion information`);

  } catch (error) {
    console.error(`Failed to update tracking comment: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Generate comment body for branch update
 */
function createBranchUpdateCommentBody(context: ParsedGitHubContext, branchName: string): string {
  const entityType = context.isPR ? "PR" : "issue";
  const timestamp = new Date().toISOString();

  return `## 🤖 Claude Code Processing Started

Hi! I'm Claude Code, and I've started processing this ${entityType}.

**Status:** 🌿 Branch created  
**Started:** ${timestamp}  
**Triggered by:** @${context.actor}  
**Working branch:** [\`${branchName}\`](https://github.com/${context.repository.full_name}/tree/${branchName})

I'll update this comment as I make progress. Here's what I'll be doing:

1. ✅ Analyzing the ${entityType} description and requirements
2. ✅ Creating a dedicated branch for my changes  
3. 🔄 Writing and testing the necessary code
4. ⏳ Documenting any changes made
5. ⏳ Running tests and ensuring quality

---

*This is an automated comment from our Agentic Coding System. I'm powered by Claude Code SDK and running on our Nomad cluster.*`;
}

/**
 * Generate comment body for job status update
 */
function createJobStatusCommentBody(context: ParsedGitHubContext, jobId: string, status: string): string {
  const entityType = context.isPR ? "PR" : "issue";
  const timestamp = new Date().toISOString();

  const statusEmoji = {
    running: "🔄",
    completed: "✅", 
    failed: "❌"
  }[status] || "🔄";

  const statusText = {
    running: "Processing in progress",
    completed: "Processing completed",
    failed: "Processing failed"
  }[status] || "Processing";

  return `## 🤖 Claude Code Processing Started

Hi! I'm Claude Code, and I've started processing this ${entityType}.

**Status:** ${statusEmoji} ${statusText}  
**Last updated:** ${timestamp}  
**Triggered by:** @${context.actor}  
**Job ID:** \`${jobId}\`

I'll update this comment as I make progress. Here's what I'll be doing:

1. ✅ Analyzing the ${entityType} description and requirements
2. ✅ Creating a dedicated branch for my changes  
3. ${status === "running" ? "🔄" : status === "completed" ? "✅" : "❌"} Writing and testing the necessary code
4. ${status === "completed" ? "✅" : "⏳"} Documenting any changes made
5. ${status === "completed" ? "✅" : "⏳"} Running tests and ensuring quality

---

*This is an automated comment from our Agentic Coding System. I'm powered by Claude Code SDK and running on our Nomad cluster.*`;
}

/**
 * Generate comment body for completion
 */
function createCompletionCommentBody(
  context: ParsedGitHubContext, 
  result: {
    branchName?: string;
    pullRequestNumber?: number;
    summary: string;
    filesChanged: string[];
  }
): string {
  const entityType = context.isPR ? "PR" : "issue";
  const timestamp = new Date().toISOString();

  let branchInfo = "";
  if (result.branchName) {
    branchInfo = `**Branch:** [\`${result.branchName}\`](https://github.com/${context.repository.full_name}/tree/${result.branchName})  \n`;
  }

  let prInfo = "";
  if (result.pullRequestNumber) {
    prInfo = `**Pull Request:** [#${result.pullRequestNumber}](https://github.com/${context.repository.full_name}/pull/${result.pullRequestNumber})  \n`;
  }

  const filesInfo = result.filesChanged.length > 0 
    ? `**Files modified:** ${result.filesChanged.length} files\n${result.filesChanged.map(f => `- \`${f}\``).join('\n')}\n\n`
    : "";

  return `## ✅ Claude Code Processing Complete

I've successfully processed this ${entityType}!

**Status:** ✅ Completed  
**Completed:** ${timestamp}  
**Triggered by:** @${context.actor}  
${branchInfo}${prInfo}

## Summary

${result.summary}

${filesInfo}**Next steps:**
- Review the changes in the branch/PR above
- Test the implementation
- Merge when ready

---

*This is an automated comment from our Agentic Coding System. I'm powered by Claude Code SDK and running on our Nomad cluster.*`;
}