import { GitHubAppClient } from './github-app-client';

export class RepoDiscovery {
  private githubApp: GitHubAppClient;
  private pattern: string;

  constructor(githubApp: GitHubAppClient, pattern: string = 'deepiri-.*') {
    this.githubApp = githubApp;
    this.pattern = pattern;
  }

  async discoverRepos(): Promise<string[]> {
    try {
      const allRepos = await this.githubApp.listOrgRepos(this.pattern);
      
      // Filter to only active, non-archived repos
      const activeRepos = allRepos.filter(async (repo) => {
        try {
          const state = await this.githubApp.fetchRepoState(repo);
          return !state.archived && !state.disabled;
        } catch {
          return false; // Skip repos we can't access
        }
      });

      // Wait for all checks to complete
      const results = await Promise.all(
        activeRepos.map(async (repo) => {
          try {
            const state = await this.githubApp.fetchRepoState(repo);
            return { repo, active: !state.archived && !state.disabled };
          } catch {
            return { repo, active: false };
          }
        })
      );

      return results.filter(r => r.active).map(r => r.repo);
    } catch (error: any) {
      throw new Error(`Failed to discover repos: ${error.message}`);
    }
  }

  async getCriticalRepos(): Promise<string[]> {
    // Auto-discover all repos matching pattern
    const discovered = await this.discoverRepos();
    
    // Prioritize core repos
    const coreRepos = [
      'deepiri-platform',
      'deepiri-core-api',
      'diri-cyrex',
      'deepiri-web-frontend',
    ];

    const critical: string[] = [];
    
    // Add core repos first (if they exist)
    for (const coreRepo of coreRepos) {
      const fullName = discovered.find(r => r.includes(coreRepo));
      if (fullName) {
        critical.push(fullName);
      }
    }

    // Add other discovered repos
    for (const repo of discovered) {
      if (!critical.includes(repo)) {
        critical.push(repo);
      }
    }

    return critical;
  }
}

