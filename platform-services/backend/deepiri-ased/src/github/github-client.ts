import { GitHubAPI } from './github-api';
import { AccessResult } from './github-types';

export class GitHubClient {
  private api: GitHubAPI;

  constructor(tokenA: string, tokenB: string, org: string) {
    this.api = new GitHubAPI(tokenA, tokenB, org);
  }

  async checkAccess(repo: string, token: 'A' | 'B'): Promise<AccessResult> {
    return this.api.checkAccess(repo, token);
  }

  async fetchRepoState(repo: string) {
    return this.api.fetchRepoState(repo);
  }

  async fetchRepoFingerprint(repo: string) {
    return this.api.fetchRepoFingerprint(repo);
  }

  async fetchSubmoduleConfig(repo: string) {
    return this.api.fetchSubmoduleConfig(repo);
  }

  async fetchWorkflowFiles(repo: string) {
    return this.api.fetchWorkflowFiles(repo);
  }

  async createCanaryBranch(repo: string): Promise<boolean> {
    return this.api.createCanaryBranch(repo);
  }

  async deleteCanaryBranch(repo: string, branchName: string): Promise<boolean> {
    return this.api.deleteCanaryBranch(repo, branchName);
  }

  async deleteRepository(repo: string): Promise<boolean> {
    return this.api.deleteRepository(repo);
  }

  async fetchAuditLog(org: string, since?: Date) {
    return this.api.fetchAuditLog(org, since);
  }
}

