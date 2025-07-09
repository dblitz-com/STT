import { GITHUB_SERVER_URL } from "../../api/config";

export const SPINNER_HTML =
  '<img src="https://github.com/user-attachments/assets/5ac382c7-e004-429b-8e35-7feb3e8f9c6f" width="14px" height="14px" style="vertical-align: middle; margin-left: 4px;" />';

export function createJobRunLink(
  owner: string,
  repo: string,
  runId: string,
): string {
  const jobRunUrl = `${GITHUB_SERVER_URL}/${owner}/${repo}/actions/runs/${runId}`;
  return `[View job run](${jobRunUrl})`;
}

export function createBranchLink(
  owner: string,
  repo: string,
  branchName: string,
): string {
  const branchUrl = `${GITHUB_SERVER_URL}/${owner}/${repo}/tree/${branchName}`;
  return `\n[View branch](${branchUrl})`;
}

export function createCommentBody(
  jobRunLink: string,
  branchLink: string = "",
  branchName?: string,
  triggeredBy?: string,
  status: 'started' | 'working' | 'completed' | 'failed' = 'started'
): string {
  const timestamp = new Date().toISOString();
  const statusIcon = status === 'started' ? '🌿' : status === 'working' ? '🔄' : status === 'completed' ? '✅' : '❌';
  const statusText = status === 'started' ? 'Branch created' : 
                     status === 'working' ? 'Processing' :
                     status === 'completed' ? 'Completed' : 'Failed';
  
  const branchInfo = branchName ? `\nWorking branch: \`${branchName}\`` : '';
  const triggerInfo = triggeredBy ? `\nTriggered by: @${triggeredBy}` : '';
  
  return `🤖 Claude Code Processing Started
Hi! I'm Claude Code, and I've started processing this issue.

Status: ${statusIcon} ${statusText}
Started: ${timestamp}${triggerInfo}${branchInfo}

I'll update this comment as I make progress. Here's what I'll be doing:

✅ Analyzing the issue description and requirements
${branchName ? '✅' : '⏳'} Creating a dedicated branch for my changes
🔄 Writing and testing the necessary code
⏳ Documenting any changes made
⏳ Running tests and ensuring quality

${jobRunLink}${branchLink}

This is an automated comment created by Claude Code.`;
}
