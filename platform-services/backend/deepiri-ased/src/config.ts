import dotenv from 'dotenv';

dotenv.config();

export interface ServiceConfig {
  detection: {
    stateInvariant: {
      enabled: boolean;
      checkInterval: number; // minutes
      baselineHash?: string;
    };
    dualToken: {
      enabled: boolean;
      tokenA: string;
      tokenB: string;
    };
    negativeAuth: {
      enabled: boolean;
      auditLogInterval: number; // minutes
    };
    writeCanary: {
      enabled: boolean;
      interval: number; // minutes
    };
    crossRepo: {
      enabled: boolean;
      criticalRepos: string[];
      failureThreshold: number; // 0.0 to 1.0
    };
    temporalConsistency: {
      enabled: boolean;
      requiredFailures: number;
      timeWindow: number; // hours
    };
  };
  scoring: {
    events: Record<string, number>;
    decay: {
      rate: number; // per hour
      minScore: number;
    };
  };
  response: {
    thresholds: {
      lock: number;
      warn: number;
      delete: number;
      immediate: number;
    };
    gracePeriods: {
      lock: number; // hours
      warn: number; // hours
      delete: number; // hours
      immediate: number; // hours
    };
    backupBeforeDelete: boolean;
    reversibilityWindow: number; // hours
  };
  notifications: {
    email?: string;
    slackWebhook?: string;
    smsApiKey?: string;
  };
  github: {
    org: string;
    // Option 1: Personal Access Tokens (legacy)
    tokenA?: string;
    tokenB?: string;
    // Option 2: GitHub App (preferred)
    appId?: string;
    installationId?: string;
    privateKey?: string;
    // Auto-discovery
    autoDiscoverRepos: boolean;
    repoPattern?: string;
  };
  storage: {
    baselineUrl?: string;
    baselineKey?: string;
    auditLogUrl?: string;
    auditLogKey?: string;
  };
  server: {
    port: number;
    logLevel: string;
  };
}

export function loadConfig(): ServiceConfig {
  const criticalRepos = (process.env.CRITICAL_REPOS || '').split(',').filter(Boolean);

  return {
    detection: {
      stateInvariant: {
        enabled: true,
        checkInterval: parseInt(process.env.STATE_CHECK_INTERVAL || '5', 10),
        baselineHash: process.env.BASELINE_HASH,
      },
      dualToken: {
        enabled: true,
        tokenA: process.env.GITHUB_TOKEN_A || '',
        tokenB: process.env.GITHUB_TOKEN_B || '',
      },
      negativeAuth: {
        enabled: true,
        auditLogInterval: parseInt(process.env.AUDIT_LOG_INTERVAL || '15', 10),
      },
      writeCanary: {
        enabled: true,
        interval: parseInt(process.env.WRITE_CANARY_INTERVAL || '60', 10),
      },
      crossRepo: {
        enabled: true,
        criticalRepos: criticalRepos.length > 0 ? criticalRepos : ['deepiri-platform'],
        failureThreshold: 0.5,
      },
      temporalConsistency: {
        enabled: true,
        requiredFailures: parseInt(process.env.TEMPORAL_CONSISTENCY_FAILURES || '12', 10),
        timeWindow: parseInt(process.env.TEMPORAL_CONSISTENCY_HOURS || '6', 10),
      },
    },
    scoring: {
      events: {
        admin_removed: 5,
        repo_transferred: 10,
        permission_downgraded: 4,
        branch_protection_removed: 4,
        write_failure: 3,
        state_invariant_break: 5,
        dual_token_disagreement: 6,
        dual_token_both_fail: 8,
      },
      decay: {
        rate: parseInt(process.env.RISK_DECAY_RATE || '1', 10),
        minScore: 0,
      },
    },
    response: {
      thresholds: {
        lock: parseInt(process.env.RISK_LOCK_THRESHOLD || '6', 10),
        warn: parseInt(process.env.RISK_WARN_THRESHOLD || '10', 10),
        delete: parseInt(process.env.RISK_DELETE_THRESHOLD || '10', 10),
        immediate: parseInt(process.env.RISK_IMMEDIATE_THRESHOLD || '15', 10),
      },
      gracePeriods: {
        lock: parseInt(process.env.GRACE_PERIOD_LOCK || '24', 10),
        warn: parseInt(process.env.GRACE_PERIOD_WARN || '48', 10),
        delete: parseInt(process.env.GRACE_PERIOD_DELETE || '72', 10),
        immediate: parseInt(process.env.GRACE_PERIOD_IMMEDIATE || '0', 10),
      },
      backupBeforeDelete: process.env.BACKUP_BEFORE_DELETE === 'true',
      reversibilityWindow: parseInt(process.env.REVERSIBILITY_WINDOW || '168', 10),
    },
    notifications: {
      email: process.env.NOTIFICATION_EMAIL,
      slackWebhook: process.env.NOTIFICATION_SLACK_WEBHOOK,
      smsApiKey: process.env.NOTIFICATION_SMS_API_KEY,
    },
    github: {
      org: process.env.GITHUB_ORG || 'Team-Deepiri',
      // Personal Access Tokens (legacy, for backward compatibility)
      tokenA: process.env.GITHUB_TOKEN_A,
      tokenB: process.env.GITHUB_TOKEN_B,
      // GitHub App (preferred method)
      appId: process.env.GITHUB_APP_ID,
      installationId: process.env.GITHUB_INSTALLATION_ID,
      privateKey: process.env.GITHUB_APP_PRIVATE_KEY,
      // Auto-discovery
      autoDiscoverRepos: process.env.AUTO_DISCOVER_REPOS !== 'false',
      repoPattern: process.env.REPO_PATTERN || 'deepiri-.*',
    },
    storage: {
      baselineUrl: process.env.BASELINE_STORAGE_URL,
      baselineKey: process.env.BASELINE_STORAGE_KEY,
      auditLogUrl: process.env.AUDIT_LOG_STORAGE_URL,
      auditLogKey: process.env.AUDIT_LOG_STORAGE_KEY,
    },
    server: {
      port: parseInt(process.env.PORT || '5010', 10),
      logLevel: process.env.LOG_LEVEL || 'info',
    },
  };
}

