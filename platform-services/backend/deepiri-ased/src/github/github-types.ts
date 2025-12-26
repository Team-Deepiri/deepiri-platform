export interface RepoState {
  owner: string;
  admins: string[];
  branchProtection: BranchProtectionRule[];
  webhooks: WebhookConfig[];
  defaultBranch: string;
  visibility: 'private' | 'public';
  archived: boolean;
  disabled: boolean;
}

export interface BranchProtectionRule {
  branch: string;
  requiredReviewers: number;
  requiredStatusChecks: string[];
  enforceAdmins: boolean;
  allowForcePush: boolean;
  allowDeletions: boolean;
}

export interface WebhookConfig {
  id: number;
  url: string;
  events: string[];
  active: boolean;
}

export interface RepoFingerprint {
  repoId: number;
  createdAt: Date;
  rootCommitHash: string;
  ownerOrgId: number;
  defaultBranchSha: string;
}

export interface SubmoduleConfig {
  path: string;
  url: string;
  commitSha: string;
}

export interface WorkflowConfig {
  path: string;
  contentHash: string;
}

export interface AccessResult {
  hasAccess: boolean;
  adminAccess: boolean;
  readAccess: boolean;
  writeAccess: boolean;
  error?: string;
  statusCode?: number;
}

export interface NegativeAuthEvent {
  type: 'admin_removed' | 'repo_transferred' | 'permission_downgraded' | 
        'branch_protection_removed' | 'webhook_deleted' | 'token_revoked';
  timestamp: Date;
  severity: number;
  repo?: string;
  details?: Record<string, any>;
}

export interface SecurityEvent {
  type: string;
  timestamp: Date;
  severity: number;
  repo?: string;
}

export interface BaselineConfig {
  version: string;
  timestamp: Date;
  repos: {
    [repoName: string]: {
      stateHash: string;
      fingerprint: RepoFingerprint;
      submodules: SubmoduleConfig[];
      workflows: WorkflowConfig[];
      admins: string[];
      branchProtection: BranchProtectionRule[];
    };
  };
}

