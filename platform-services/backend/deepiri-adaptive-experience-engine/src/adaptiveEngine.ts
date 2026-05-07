import { Request, Response } from 'express';
import axios from 'axios';
import { secureLog } from '@team-deepiri/shared-utils';
import { publishAdaptiveExperienceGenerated } from './streaming/eventPublisher';

const CYREX_URL = process.env.CYREX_URL || 'http://cyrex:8000';

export interface ExperienceContext {
  userId?: string;
  userState?: Record<string, any>;
  surface?: 'onboarding' | 'learning' | 'contributor' | 'gamification' | 'workflow' | 'agentic';
  difficulty?: 'beginner' | 'intermediate' | 'advanced' | 'expert';
  domain?: string;
  preferences?: Record<string, any>;
}

export interface MissionPrompt {
  id: string;
  type: 'objective' | 'mission' | 'prompt' | 'quest' | 'task';
  title: string;
  description: string;
  difficulty: number;
  estimatedDuration: number;
  prerequisites: string[];
  rewards: Record<string, number>;
  adaptivePacing?: {
    cooldown: number;
    maxPerDay: number;
    smartDelay: boolean;
  };
  constraints?: {
    minLevel?: number;
    requiredBadges?: string[];
    blockedDomains?: string[];
  };
  metadata: Record<string, any>;
}

export interface OnboardingPath {
  id: string;
  userType: string;
  steps: {
    order: number;
    type: 'challenge' | 'tutorial' | 'choice' | 'checkpoint';
    content: string;
    expectedOutcome: string;
    allowSkip: boolean;
  }[];
  branching: boolean;
  estimatedTime: number;
}

export interface LearningPath {
  id: string;
  subject: string;
  levels: {
    level: number;
    objectives: string[];
    assessmentThreshold: number;
    nextLevelPrerequisites: string[];
  }[];
  adaptiveDifficulty: boolean;
  personalization: Record<string, any>;
}

export class AdaptiveExperienceEngine {
  async generateMission(ctx: ExperienceContext): Promise<MissionPrompt> {
    const response = await axios.post(`${CYREX_URL}/agent/challenge/generate`, {
      type: 'mission',
      context: ctx,
      adaptive: true
    });
    return response.data;
  }

  async generateObjective(ctx: ExperienceContext): Promise<MissionPrompt> {
    const response = await axios.post(`${CYREX_URL}/agent/challenge/generate`, {
      type: 'objective',
      context: ctx,
      adaptive: true
    });
    return response.data;
  }

  async generatePrompt(ctx: ExperienceContext): Promise<MissionPrompt> {
    const response = await axios.post(`${CYREX_URL}/agent/challenge/generate`, {
      type: 'prompt',
      context: ctx,
      adaptive: true
    });
    return response.data;
  }

  async generateQuest(ctx: ExperienceContext): Promise<MissionPrompt> {
    const response = await axios.post(`${CYREX_URL}/agent/challenge/generate`, {
      type: 'quest',
      context: ctx,
      adaptive: true
    });
    return response.data;
  }

  async buildOnboardingPath(userType: string): Promise<OnboardingPath> {
    const response = await axios.post(`${CYREX_URL}/agent/path/onboarding`, { userType });
    return response.data;
  }

  async buildLearningPath(subject: string, userLevel: number): Promise<LearningPath> {
    const response = await axios.post(`${CYREX_URL}/agent/path/learning`, { subject, userLevel });
    return response.data;
  }

  async getNextBestAction(userId: string, context: ExperienceContext): Promise<MissionPrompt | null> {
    try {
      const response = await axios.post(`${CYREX_URL}/agent/next-best-action`, {
        userId,
        context
      });
      return response.data;
    } catch (error) {
      secureLog('warn', 'NBA fetch failed, returning null', { error });
      return null;
    }
  }

  async applyPacingPolicy(userId: string, missionId: string): Promise<boolean> {
    const response = await axios.post(`${CYREX_URL}/agent/pacing/check`, {
      userId,
      missionId
    });
    return response.data.allowed;
  }

  async validateConstraints(userId: string, mission: MissionPrompt): Promise<{
    allowed: boolean;
    missing: string[];
    blocked: string[];
  }> {
    const response = await axios.post(`${CYREX_URL}/agent/constraints/validate`, {
      userId,
      mission
    });
    return response.data;
  }
}

export const experienceEngine = new AdaptiveExperienceEngine();

export async function handleGenerateMission(req: Request, res: Response): Promise<void> {
  try {
    const mission = await experienceEngine.generateMission(req.body);
    publishAdaptiveExperienceGenerated(req.body?.userId, 'mission', mission).catch(() => {});
    res.json(mission);
  } catch (error: any) {
    secureLog('error', 'Mission generation error:', error);
    res.status(500).json({ error: 'Failed to generate mission' });
  }
}

export async function handleGenerateObjective(req: Request, res: Response): Promise<void> {
  try {
    const objective = await experienceEngine.generateObjective(req.body);
    publishAdaptiveExperienceGenerated(req.body?.userId, 'objective', objective).catch(() => {});
    res.json(objective);
  } catch (error: any) {
    secureLog('error', 'Objective generation error:', error);
    res.status(500).json({ error: 'Failed to generate objective' });
  }
}

export async function handleGeneratePrompt(req: Request, res: Response): Promise<void> {
  try {
    const prompt = await experienceEngine.generatePrompt(req.body);
    publishAdaptiveExperienceGenerated(req.body?.userId, 'prompt', prompt).catch(() => {});
    res.json(prompt);
  } catch (error: any) {
    secureLog('error', 'Prompt generation error:', error);
    res.status(500).json({ error: 'Failed to generate prompt' });
  }
}

export async function handleBuildOnboarding(req: Request, res: Response): Promise<void> {
  try {
    const { userType } = req.body;
    const path = await experienceEngine.buildOnboardingPath(userType);
    res.json(path);
  } catch (error: any) {
    secureLog('error', 'Onboarding path generation error:', error);
    res.status(500).json({ error: 'Failed to generate onboarding path' });
  }
}

export async function handleBuildLearning(req: Request, res: Response): Promise<void> {
  try {
    const { subject, userLevel } = req.body;
    const path = await experienceEngine.buildLearningPath(subject, userLevel);
    res.json(path);
  } catch (error: any) {
    secureLog('error', 'Learning path generation error:', error);
    res.status(500).json({ error: 'Failed to generate learning path' });
  }
}

export async function handleNextBestAction(req: Request, res: Response): Promise<void> {
  try {
    const { userId, context } = req.body;
    const action = await experienceEngine.getNextBestAction(userId, context);
    res.json(action);
  } catch (error: any) {
    secureLog('error', 'Next-best-action error:', error);
    res.status(500).json({ error: 'Failed to get next-best-action' });
  }
}

export async function handleCheckPacing(req: Request, res: Response): Promise<void> {
  try {
    const { userId, missionId } = req.body;
    const allowed = await experienceEngine.applyPacingPolicy(userId, missionId);
    res.json({ allowed });
  } catch (error: any) {
    secureLog('error', 'Pacing check error:', error);
    res.status(500).json({ error: 'Failed to check pacing policy' });
  }
}
