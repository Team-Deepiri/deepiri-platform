import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';
import axios from 'axios';

export interface TenantPolicy {
  id: string;
  tenantId: string;
  name: string;
  scoringRules: {
    action: string;
    points: number;
    multiplier?: number;
    cooldown?: number;
    dailyCap?: number;
  }[];
  antiAbuse: {
    rateLimitPerHour: number;
    rateLimitPerDay: number;
    trustThreshold: number;
    anomalyFlags: string[];
    suspiciousPatterns: string[];
  };
  fraudControls: {
    maxPerUser: number;
    maxPerIP: number;
    requireVerification: boolean;
    blockVPN: boolean;
  };
}

export interface IncentiveLedgerEntry {
  id: string;
  tenantId: string;
  userId: string;
  action: string;
  points: number;
  currency?: string;
  balance: number;
  timestamp: string;
  idempotencyKey: string;
  metadata: Record<string, any>;
}

export interface TrustScore {
  userId: string;
  tenantId: string;
  score: number;
  level: 'new' | 'trusted' | 'verified' | 'trusted_plus';
  factors: {
    age: number;
    activity: number;
    verification: boolean;
    anomalyScore: number;
  };
}

export interface Milestone {
  id: string;
  tenantId: string;
  name: string;
  criteria: {
    type: 'points' | 'streak' | 'actions' | 'custom';
    target: number;
    window?: number;
  };
  reward: {
    points: number;
    badge?: string;
    currency?: string;
  };
}

export class IncentiveEngineCore {
  private tenants: Map<string, TenantPolicy> = new Map();

  async awardPoints(
    tenantId: string,
    userId: string,
    action: string,
    idempotencyKey: string,
    metadata?: Record<string, any>
  ): Promise<IncentiveLedgerEntry> {
    const policy = await this.getTenantPolicy(tenantId);
    
    const rateCheck = await this.checkRateLimits(tenantId, userId, action);
    if (!rateCheck.allowed) {
      throw new Error(`Rate limit exceeded: ${rateCheck.reason}`);
    }

    const trustCheck = await this.checkTrustThreshold(tenantId, userId);
    if (!trustCheck.allowed) {
      throw new Error(`Trust threshold not met: ${trustCheck.reason}`);
    }

    const rule = policy.scoringRules.find(r => r.action === action);
    const points = rule ? rule.points : 0;

    const entry: IncentiveLedgerEntry = {
      id: `ledger-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      tenantId,
      userId,
      action,
      points,
      balance: await this.getBalance(tenantId, userId) + points,
      timestamp: new Date().toISOString(),
      idempotencyKey,
      metadata: metadata || {}
    };

    await this.recordLedgerEntry(entry);
    return entry;
  }

  async checkRateLimits(
    tenantId: string,
    userId: string,
    action: string
  ): Promise<{ allowed: boolean; reason?: string; remaining: number }> {
    const policy = await this.getTenantPolicy(tenantId);
    const rule = policy.scoringRules.find(r => r.action === action);
    
    if (!rule) return { allowed: true, remaining: Infinity };

    const now = Date.now();
    const hourAgo = now - 3600000;
    const dayAgo = now - 86400000;

    const hourlyCount = await this.getActionCount(tenantId, userId, action, hourAgo);
    const dailyCount = await this.getActionCount(tenantId, userId, action, dayAgo);

    if (hourlyCount >= (rule.cooldown || 0)) {
      return { allowed: false, reason: 'Hourly rate limit', remaining: 0 };
    }
    if (dailyCount >= (rule.dailyCap || Infinity)) {
      return { allowed: false, reason: 'Daily cap reached', remaining: 0 };
    }

    return { allowed: true, remaining: (rule.dailyCap || Infinity) - dailyCount };
  }

  async checkTrustThreshold(
    tenantId: string,
    userId: string
  ): Promise<{ allowed: boolean; level?: string; reason?: string }> {
    const trust = await this.getTrustScore(tenantId, userId);
    const policy = await this.getTenantPolicy(tenantId);

    if (trust.score < policy.antiAbuse.trustThreshold) {
      return { allowed: false, level: trust.level, reason: 'Trust below threshold' };
    }

    for (const flag of policy.antiAbuse.anomalyFlags) {
      if (await this.checkAnomaly(tenantId, userId, flag)) {
        return { allowed: false, level: trust.level, reason: `Anomaly detected: ${flag}` };
      }
    }

    return { allowed: true, level: trust.level };
  }

  async getTrustScore(tenantId: string, userId: string): Promise<TrustScore> {
    return {
      userId,
      tenantId,
      score: 75,
      level: 'trusted',
      factors: {
        age: 30,
        activity: 100,
        verification: true,
        anomalyScore: 0.1
      }
    };
  }

  async getTenantPolicy(tenantId: string): Promise<TenantPolicy> {
    if (this.tenants.has(tenantId)) {
      return this.tenants.get(tenantId)!;
    }

    const policy: TenantPolicy = {
      id: `policy-${tenantId}`,
      tenantId,
      name: 'default',
      scoringRules: [
        { action: 'contribution', points: 10 },
        { action: 'review', points: 5 },
        { action: 'help', points: 15 }
      ],
      antiAbuse: {
        rateLimitPerHour: 100,
        rateLimitPerDay: 500,
        trustThreshold: 50,
        anomalyFlags: ['rapid_fire', 'sync_burst', 'geo_improbable'],
        suspiciousPatterns: ['bot_signature', 'vpn_fingerprint']
      },
      fraudControls: {
        maxPerUser: 1000,
        maxPerIP: 50,
        requireVerification: false,
        blockVPN: false
      }
    };

    this.tenants.set(tenantId, policy);
    return policy;
  }

  async recordLedgerEntry(entry: IncentiveLedgerEntry): Promise<void> {
    secureLog('info', 'Ledger entry recorded', { entryId: entry.id, tenantId: entry.tenantId });
  }

  async getBalance(tenantId: string, userId: string): Promise<number> {
    return 0;
  }

  async getActionCount(
    tenantId: string,
    userId: string,
    action: string,
    since: number
  ): Promise<number> {
    return 0;
  }

  async checkAnomaly(
    tenantId: string,
    userId: string,
    anomalyType: string
  ): Promise<boolean> {
    return false;
  }
}

export const incentiveEngine = new IncentiveEngineCore();

export async function handleAwardPoints(req: Request, res: Response): Promise<void> {
  try {
    const { tenantId, userId, action, idempotencyKey, metadata } = req.body;
    const entry = await incentiveEngine.awardPoints(tenantId, userId, action, idempotencyKey, metadata);
    res.json(entry);
  } catch (error: any) {
    secureLog('error', 'Award points error:', error);
    res.status(400).json({ error: error.message });
  }
}

export async function handleGetBalance(req: Request, res: Response): Promise<void> {
  try {
    const { tenantId, userId } = req.body;
    const balance = await incentiveEngine.getBalance(tenantId, userId);
    res.json({ tenantId, userId, balance });
  } catch (error: any) {
    secureLog('error', 'Get balance error:', error);
    res.status(500).json({ error: 'Failed to get balance' });
  }
}

export async function handleGetTrustScore(req: Request, res: Response): Promise<void> {
  try {
    const { tenantId, userId } = req.body;
    const trust = await incentiveEngine.getTrustScore(tenantId, userId);
    res.json(trust);
  } catch (error: any) {
    secureLog('error', 'Get trust score error:', error);
    res.status(500).json({ error: 'Failed to get trust score' });
  }
}

export async function handleCheckRateLimits(req: Request, res: Response): Promise<void> {
  try {
    const { tenantId, userId, action } = req.body;
    const check = await incentiveEngine.checkRateLimits(tenantId, userId, action);
    res.json(check);
  } catch (error: any) {
    secureLog('error', 'Rate limit check error:', error);
    res.status(500).json({ error: 'Failed to check rate limits' });
  }
}

export async function handleCheckTrust(req: Request, res: Response): Promise<void> {
  try {
    const { tenantId, userId } = req.body;
    const check = await incentiveEngine.checkTrustThreshold(tenantId, userId);
    res.json(check);
  } catch (error: any) {
    secureLog('error', 'Trust check error:', error);
    res.status(500).json({ error: 'Failed to check trust' });
  }
}