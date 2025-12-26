import { Octokit } from '@octokit/rest';
import { createAppAuth } from '@octokit/auth-app';
import { AccessResult } from './github-types';

export class GitHubAppClient {
  private octokit: Octokit;
  private appId: string;
  private installationId: string;
  private org: string;

  constructor(appId: string, installationId: string, privateKey: string, org: string) {
    this.appId = appId;
    this.installationId = installationId;
    this.org = org;

    this.octokit = new Octokit({
      authStrategy: createAppAuth,
      auth: {
        appId: appId,
        privateKey: privateKey,
        installationId: installationId,
      },
    });
  }

  async checkAccess(repo: string): Promise<AccessResult> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];

    try {
      const repoData = await this.octokit.repos.get({ owner, repo: repoName });
      
      // Check admin access
      let adminAccess = false;
      try {
        await this.octokit.repos.getBranchProtection({
          owner,
          repo: repoName,
          branch: repoData.data.default_branch,
        });
        adminAccess = true;
      } catch {
        adminAccess = false;
      }

      return {
        hasAccess: true,
        adminAccess,
        readAccess: true,
        writeAccess: true, // GitHub App tokens have write access
      };
    } catch (error: any) {
      const statusCode = error.status || error.response?.status;
      return {
        hasAccess: false,
        adminAccess: false,
        readAccess: false,
        writeAccess: false,
        error: error.message,
        statusCode,
      };
    }
  }

  async listOrgRepos(pattern?: string): Promise<string[]> {
    try {
      const repos: string[] = [];
      
      // List all repos in the organization
      const iterator = this.octokit.paginate.iterator(this.octokit.repos.listForOrg, {
        org: this.org,
        type: 'all',
        per_page: 100,
      });

      for await (const { data } of iterator) {
        for (const repo of data) {
          const repoName = repo.full_name || `${this.org}/${repo.name}`;
          
          // Filter by pattern if provided
          if (!pattern || repo.name.match(new RegExp(pattern))) {
            repos.push(repoName);
          }
        }
      }

      return repos;
    } catch (error: any) {
      throw new Error(`Failed to list org repos: ${error.message}`);
    }
  }

  async fetchRepoState(repo: string) {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    const repoData = await this.octokit.repos.get({ owner, repo: repoName });
    
    // Fetch admins
    const collaborators = await this.octokit.repos.listCollaborators({
      owner,
      repo: repoName,
      affiliation: 'direct',
    });
    const admins = collaborators.data
      .filter(c => c.permissions?.admin)
      .map(c => c.login);

    // Fetch branch protection
    const branchProtection: any[] = [];
    try {
      const protection = await this.octokit.repos.getBranchProtection({
        owner,
        repo: repoName,
        branch: repoData.data.default_branch,
      });
      branchProtection.push({
        branch: repoData.data.default_branch,
        requiredReviewers: protection.data.required_pull_request_reviews?.required_approving_review_count || 0,
        requiredStatusChecks: protection.data.required_status_checks?.contexts || [],
        enforceAdmins: protection.data.enforce_admins?.enabled || false,
        allowForcePush: protection.data.allow_force_pushes?.enabled || false,
        allowDeletions: protection.data.allow_deletions?.enabled || false,
      });
    } catch {
      // No branch protection
    }

    // Fetch webhooks
    const webhooks: any[] = [];
    try {
      const hooks = await this.octokit.repos.listWebhooks({ owner, repo: repoName });
      webhooks.push(...hooks.data.map(hook => ({
        id: hook.id,
        url: hook.config.url,
        events: hook.events,
        active: hook.active,
      })));
    } catch {
      // No webhooks or no access
    }

    return {
      owner: repoData.data.owner.login,
      admins,
      branchProtection,
      webhooks,
      defaultBranch: repoData.data.default_branch,
      visibility: repoData.data.private ? 'private' : 'public',
      archived: repoData.data.archived,
      disabled: repoData.data.disabled || false,
    };
  }

  // Delegate other methods to octokit
  async fetchRepoFingerprint(repo: string) {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    const repoData = await this.octokit.repos.get({ owner, repo: repoName });
    
    let rootCommitHash = '';
    try {
      const allCommits = await this.octokit.paginate(
        this.octokit.repos.listCommits,
        { owner, repo: repoName, per_page: 100 }
      );
      if (allCommits.length > 0) {
        rootCommitHash = allCommits[allCommits.length - 1].sha;
      }
    } catch {
      // Could not fetch commits
    }

    let defaultBranchSha = '';
    try {
      const branch = await this.octokit.repos.getBranch({
        owner,
        repo: repoName,
        branch: repoData.data.default_branch,
      });
      defaultBranchSha = branch.data.commit.sha;
    } catch {
      // Could not fetch branch
    }

    return {
      repoId: repoData.data.id,
      createdAt: new Date(repoData.data.created_at),
      rootCommitHash,
      ownerOrgId: repoData.data.owner.id,
      defaultBranchSha,
    };
  }

  async createCanaryBranch(repo: string): Promise<boolean> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    const branchName = `canary-${Date.now()}`;
    
    try {
      const defaultBranch = await this.octokit.repos.getBranch({
        owner,
        repo: repoName,
        branch: 'main',
      }).catch(() => 
        this.octokit.repos.getBranch({
          owner,
          repo: repoName,
          branch: 'master',
        })
      );

      await this.octokit.git.createRef({
        owner,
        repo: repoName,
        ref: `refs/heads/${branchName}`,
        sha: defaultBranch.data.commit.sha,
      });

      return true;
    } catch (error: any) {
      if (error.status === 403 || error.status === 404) {
        return false;
      }
      throw error;
    }
  }

  async deleteCanaryBranch(repo: string, branchName: string): Promise<boolean> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    try {
      await this.octokit.git.deleteRef({
        owner,
        repo: repoName,
        ref: `heads/${branchName}`,
      });
      return true;
    } catch (error: any) {
      if (error.status === 403 || error.status === 404) {
        return false;
      }
      throw error;
    }
  }

  async deleteRepository(repo: string): Promise<boolean> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    try {
      await this.octokit.repos.delete({ owner, repo: repoName });
      return true;
    } catch (error: any) {
      throw new Error(`Failed to delete repository ${repo}: ${error.message}`);
    }
  }

  async fetchAuditLog(org: string, since?: Date): Promise<any[]> {
    try {
      // GitHub Apps can access audit logs if they have the permission
      const events = await this.octokit.activity.listRepoEvents({
        owner: org,
        repo: 'deepiri-platform',
      });
      
      return events.data
        .filter(event => !since || new Date(event.created_at) >= since)
        .map(event => ({
          type: event.type,
          timestamp: new Date(event.created_at),
          actor: event.actor?.login,
          repo: event.repo?.name,
          payload: event.payload,
        }));
    } catch {
      return [];
    }
  }
}

