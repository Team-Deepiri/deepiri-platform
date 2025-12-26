import { GitHubClient } from '../github/github-client';

export class WriteCanaryDetector {
  private githubClient: GitHubClient;
  private canaryBranches: Map<string, string> = new Map();

  constructor(githubClient: GitHubClient) {
    this.githubClient = githubClient;
  }

  async check(repo: string): Promise<number> {
    let failures = 0;
    const maxAttempts = 3;

    for (let i = 0; i < maxAttempts; i++) {
      try {
        // Attempt to create canary branch
        const success = await this.githubClient.createCanaryBranch(repo);
        
        if (success) {
          // Successfully created, try to delete it
          const branchName = `canary-${Date.now()}`;
          await this.githubClient.deleteCanaryBranch(repo, branchName);
          
          // Clean up any old canary branches
          await this.cleanupCanaryBranches(repo);
          
          return 0; // Write works, all good
        } else {
          failures++;
        }
      } catch (error: any) {
        // Check if it's an authorization error (403) or not found (404)
        if (error.status === 403 || error.status === 404) {
          failures++;
        } else {
          // Network error or other issue, don't count as write failure
          return 0;
        }
      }
    }

    // If all attempts failed, return risk score
    return failures * 3; // +3 per write failure
  }

  private async cleanupCanaryBranches(repo: string): Promise<void> {
    // Clean up old canary branches if they exist
    const oldBranch = this.canaryBranches.get(repo);
    if (oldBranch) {
      try {
        await this.githubClient.deleteCanaryBranch(repo, oldBranch);
        this.canaryBranches.delete(repo);
      } catch {
        // Ignore cleanup errors
      }
    }
  }
}

