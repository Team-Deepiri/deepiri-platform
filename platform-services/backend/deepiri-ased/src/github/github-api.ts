import { Octokit } from '@octokit/rest';
import { 
  RepoState, 
  BranchProtectionRule, 
  WebhookConfig, 
  RepoFingerprint,
  SubmoduleConfig,
  WorkflowConfig,
  AccessResult
} from './github-types';

export class GitHubAPI {
  private octokitA: Octokit;
  private octokitB: Octokit;
  private org: string;

  constructor(tokenA: string, tokenB: string, org: string) {
    this.octokitA = new Octokit({ auth: tokenA });
    this.octokitB = new Octokit({ auth: tokenB });
    this.org = org;
  }

  async checkAccess(repo: string, token: 'A' | 'B'): Promise<AccessResult> {
    const octokit = token === 'A' ? this.octokitA : this.octokitB;
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];

    try {
      // Check read access
      const repoData = await octokit.repos.get({ owner, repo: repoName });
      
      // Check admin access
      let adminAccess = false;
      try {
        const permissions = await octokit.repos.getCollaboratorPermissionLevel({
          owner,
          repo: repoName,
          username: (await octokit.users.getAuthenticated()).data.login,
        });
        adminAccess = permissions.data.permission === 'admin';
      } catch {
        // If we can't check permissions, try to perform admin action
        try {
          await octokit.repos.getBranchProtection({ owner, repo: repoName, branch: 'main' });
          adminAccess = true;
        } catch {
          adminAccess = false;
        }
      }

      // Check write access by attempting to get a branch
      let writeAccess = false;
      try {
        await octokit.repos.getBranch({ owner, repo: repoName, branch: 'main' });
        writeAccess = true;
      } catch {
        writeAccess = false;
      }

      return {
        hasAccess: true,
        adminAccess,
        readAccess: true,
        writeAccess,
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

  async fetchRepoState(repo: string): Promise<RepoState> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    try {
      const repoData = await this.octokitA.repos.get({ owner, repo: repoName });
      
      // Fetch admins
      const collaborators = await this.octokitA.repos.listCollaborators({
        owner,
        repo: repoName,
        affiliation: 'direct',
      });
      const admins = collaborators.data
        .filter(c => c.permissions?.admin)
        .map(c => c.login);

      // Fetch branch protection
      const branchProtection: BranchProtectionRule[] = [];
      try {
        const protection = await this.octokitA.repos.getBranchProtection({
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
      const webhooks: WebhookConfig[] = [];
      try {
        const hooks = await this.octokitA.repos.listWebhooks({ owner, repo: repoName });
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
    } catch (error: any) {
      throw new Error(`Failed to fetch repo state for ${repo}: ${error.message}`);
    }
  }

  async fetchRepoFingerprint(repo: string): Promise<RepoFingerprint> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    try {
      const repoData = await this.octokitA.repos.get({ owner, repo: repoName });
      
      // Get root commit (first commit)
      let rootCommitHash = '';
      try {
        const commits = await this.octokitA.repos.listCommits({
          owner,
          repo: repoName,
          per_page: 1,
        });
        if (commits.data.length > 0) {
          // Get the last commit (oldest)
          const allCommits = await this.octokitA.paginate(
            this.octokitA.repos.listCommits,
            { owner, repo: repoName, per_page: 100 }
          );
          if (allCommits.length > 0) {
            rootCommitHash = allCommits[allCommits.length - 1].sha;
          }
        }
      } catch {
        // Could not fetch commits
      }

      // Get default branch SHA
      let defaultBranchSha = '';
      try {
        const branch = await this.octokitA.repos.getBranch({
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
    } catch (error: any) {
      throw new Error(`Failed to fetch repo fingerprint for ${repo}: ${error.message}`);
    }
  }

  async fetchSubmoduleConfig(repo: string): Promise<SubmoduleConfig[]> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    try {
      const content = await this.octokitA.repos.getContent({
        owner,
        repo: repoName,
        path: '.gitmodules',
      });

      if (Array.isArray(content.data) || content.data.type !== 'file') {
        return [];
      }

      // Parse .gitmodules file
      const submodules: SubmoduleConfig[] = [];
      const contentText = Buffer.from(content.data.content, 'base64').toString('utf-8');
      const lines = contentText.split('\n');
      
      let currentSubmodule: Partial<SubmoduleConfig> = {};
      for (const line of lines) {
        if (line.startsWith('[submodule')) {
          if (currentSubmodule.path) {
            submodules.push(currentSubmodule as SubmoduleConfig);
          }
          currentSubmodule = {};
        } else if (line.startsWith('\tpath = ')) {
          currentSubmodule.path = line.replace('\tpath = ', '').trim();
        } else if (line.startsWith('\turl = ')) {
          currentSubmodule.url = line.replace('\turl = ', '').trim();
        }
      }
      if (currentSubmodule.path) {
        submodules.push(currentSubmodule as SubmoduleConfig);
      }

      // Get commit SHAs for each submodule
      for (const submodule of submodules) {
        try {
          const submoduleContent = await this.octokitA.repos.getContent({
            owner,
            repo: repoName,
            path: submodule.path!,
          });
          if (Array.isArray(submoduleContent.data)) {
            // It's a directory, get the commit from git tree
            submodule.commitSha = '';
          } else {
            submodule.commitSha = submoduleContent.data.sha;
          }
        } catch {
          submodule.commitSha = '';
        }
      }

      return submodules;
    } catch {
      return [];
    }
  }

  async fetchWorkflowFiles(repo: string): Promise<WorkflowConfig[]> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    
    try {
      const workflows: WorkflowConfig[] = [];
      const content = await this.octokitA.repos.getContent({
        owner,
        repo: repoName,
        path: '.github/workflows',
      });

      if (Array.isArray(content.data)) {
        for (const item of content.data) {
          if (item.type === 'file' && item.name.endsWith('.yml') || item.name.endsWith('.yaml')) {
            try {
              const fileContent = await this.octokitA.repos.getContent({
                owner,
                repo: repoName,
                path: item.path,
              });
              if (!Array.isArray(fileContent.data) && fileContent.data.type === 'file') {
                const contentText = Buffer.from(fileContent.data.content, 'base64').toString('utf-8');
                const crypto = require('crypto');
                const hash = crypto.createHash('sha256').update(contentText).digest('hex');
                workflows.push({
                  path: item.path,
                  contentHash: hash,
                });
              }
            } catch {
              // Skip files we can't read
            }
          }
        }
      }

      return workflows;
    } catch {
      return [];
    }
  }

  async createCanaryBranch(repo: string): Promise<boolean> {
    const [owner, repoName] = repo.includes('/') ? repo.split('/') : [this.org, repo];
    const branchName = `canary-${Date.now()}`;
    
    try {
      // Get default branch SHA
      const defaultBranch = await this.octokitA.repos.getBranch({
        owner,
        repo: repoName,
        branch: 'main',
      }).catch(() => 
        this.octokitA.repos.getBranch({
          owner,
          repo: repoName,
          branch: 'master',
        })
      );

      // Create branch
      await this.octokitA.git.createRef({
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
      await this.octokitA.git.deleteRef({
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
      await this.octokitA.repos.delete({ owner, repo: repoName });
      return true;
    } catch (error: any) {
      throw new Error(`Failed to delete repository ${repo}: ${error.message}`);
    }
  }

  async fetchAuditLog(org: string, since?: Date): Promise<any[]> {
    try {
      // Note: Audit log API requires GitHub Enterprise
      // For regular GitHub, we'll use repository events instead
      const events = await this.octokitA.activity.listRepoEvents({
        owner: org,
        repo: 'deepiri-platform', // Use main repo as proxy
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

