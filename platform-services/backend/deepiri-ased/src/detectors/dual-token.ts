import { GitHubClient } from '../github/github-client';

export class DualTokenDetector {
  private githubClient: GitHubClient;

  constructor(githubClient: GitHubClient) {
    this.githubClient = githubClient;
  }

  async check(repo: string): Promise<number> {
    try {
      const [resultA, resultB] = await Promise.all([
        this.githubClient.checkAccess(repo, 'A'),
        this.githubClient.checkAccess(repo, 'B'),
      ]);

      // Both tokens lost access
      if (!resultA.hasAccess && !resultB.hasAccess) {
        return 8; // Both lost access = real event
      }

      // Disagreement between tokens
      if (resultA.hasAccess !== resultB.hasAccess) {
        return 6; // Disagreement = potential issue
      }

      // Admin access mismatch
      if (resultA.adminAccess !== resultB.adminAccess) {
        return 7; // Admin access mismatch
      }

      // Both have access and agree
      return 0;
    } catch (error: any) {
      // Network or API errors don't count as authorization failures
      return 0;
    }
  }
}

