import mongoose, { Schema, Document, Model } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('skill-tree-service');

interface ISkill {
  level: number;
  xp: number;
  unlocked: boolean;
}

interface ISkillTree extends Document {
  userId: mongoose.Types.ObjectId;
  skills: {
    timeManagement: ISkill;
    taskOrganization: ISkill;
    focus: ISkill;
    planning: ISkill;
    coding: ISkill;
    debugging: ISkill;
    codeReview: ISkill;
    architecture: ISkill;
    writing: ISkill;
    design: ISkill;
    ideation: ISkill;
    storytelling: ISkill;
    research: ISkill;
    learning: ISkill;
    noteTaking: ISkill;
    knowledgeRetention: ISkill;
    collaboration: ISkill;
    communication: ISkill;
    leadership: ISkill;
    mentoring: ISkill;
    selfAwareness: ISkill;
    adaptability: ISkill;
  };
  skillPoints: number;
  totalSkillLevel: number;
  lastUpdated: Date;
}

const SkillTreeSchema = new Schema<ISkillTree>({
  userId: { type: Schema.Types.ObjectId, required: true, unique: true },
  skills: {
    timeManagement: { level: Number, xp: Number, unlocked: Boolean },
    taskOrganization: { level: Number, xp: Number, unlocked: Boolean },
    focus: { level: Number, xp: Number, unlocked: Boolean },
    planning: { level: Number, xp: Number, unlocked: Boolean },
    coding: { level: Number, xp: Number, unlocked: Boolean },
    debugging: { level: Number, xp: Number, unlocked: Boolean },
    codeReview: { level: Number, xp: Number, unlocked: Boolean },
    architecture: { level: Number, xp: Number, unlocked: Boolean },
    writing: { level: Number, xp: Number, unlocked: Boolean },
    design: { level: Number, xp: Number, unlocked: Boolean },
    ideation: { level: Number, xp: Number, unlocked: Boolean },
    storytelling: { level: Number, xp: Number, unlocked: Boolean },
    research: { level: Number, xp: Number, unlocked: Boolean },
    learning: { level: Number, xp: Number, unlocked: Boolean },
    noteTaking: { level: Number, xp: Number, unlocked: Boolean },
    knowledgeRetention: { level: Number, xp: Number, unlocked: Boolean },
    collaboration: { level: Number, xp: Number, unlocked: Boolean },
    communication: { level: Number, xp: Number, unlocked: Boolean },
    leadership: { level: Number, xp: Number, unlocked: Boolean },
    mentoring: { level: Number, xp: Number, unlocked: Boolean },
    selfAwareness: { level: Number, xp: Number, unlocked: Boolean },
    adaptability: { level: Number, xp: Number, unlocked: Boolean }
  },
  skillPoints: { type: Number, default: 0 },
  totalSkillLevel: { type: Number, default: 0 },
  lastUpdated: { type: Date, default: Date.now }
}, { timestamps: true });

const SkillTree: Model<ISkillTree> = mongoose.model<ISkillTree>('SkillTree', SkillTreeSchema);

class SkillTreeService {
  private readonly SKILLS: string[] = [
    'timeManagement', 'taskOrganization', 'focus', 'planning',
    'coding', 'debugging', 'codeReview', 'architecture',
    'writing', 'design', 'ideation', 'storytelling',
    'research', 'learning', 'noteTaking', 'knowledgeRetention',
    'collaboration', 'communication', 'leadership', 'mentoring',
    'selfAwareness', 'adaptability'
  ];
  
  private readonly XP_PER_LEVEL = 1000;
  private readonly MAX_LEVEL = 100;

  async getSkillTree(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const skillTree = await this.getOrCreateSkillTree(new mongoose.Types.ObjectId(userId));
      res.json(skillTree);
    } catch (error) {
      logger.error('Error getting skill tree:', error);
      res.status(500).json({ error: 'Failed to get skill tree' });
    }
  }

  async upgradeSkill(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { skillName, xpAmount } = req.body;
      
      if (!skillName || !xpAmount) {
        res.status(400).json({ error: 'Missing skillName or xpAmount' });
        return;
      }

      const result = await this.awardSkillXP(
        new mongoose.Types.ObjectId(userId),
        skillName,
        xpAmount
      );
      res.json(result);
    } catch (error) {
      logger.error('Error upgrading skill:', error);
      res.status(500).json({ error: 'Failed to upgrade skill' });
    }
  }

  private async getOrCreateSkillTree(userId: mongoose.Types.ObjectId): Promise<ISkillTree> {
    try {
      let skillTree = await SkillTree.findOne({ userId });
      
      if (!skillTree) {
        skillTree = new SkillTree({
          userId,
          skills: this._initializeSkills()
        });
        await skillTree.save();
      }
      
      return skillTree;
    } catch (error) {
      logger.error('Error getting skill tree:', error);
      throw error;
    }
  }

  private _initializeSkills(): Record<string, ISkill> {
    const skills: Record<string, ISkill> = {};
    this.SKILLS.forEach(skill => {
      skills[skill] = {
        level: 1,
        xp: 0,
        unlocked: true
      };
    });
    return skills;
  }

  private async awardSkillXP(userId: mongoose.Types.ObjectId, skillName: string, xpAmount: number) {
    try {
      const skillTree = await this.getOrCreateSkillTree(userId);
      
      if (!skillTree.skills[skillName as keyof typeof skillTree.skills]) {
        throw new Error(`Invalid skill: ${skillName}`);
      }
      
      const skill = skillTree.skills[skillName as keyof typeof skillTree.skills];
      skill.xp += xpAmount;
      
      const newLevel = Math.floor(skill.xp / this.XP_PER_LEVEL) + 1;
      const leveledUp = newLevel > skill.level && newLevel <= this.MAX_LEVEL;
      
      if (leveledUp) {
        skill.level = newLevel;
        skillTree.skillPoints += 1;
        skillTree.totalSkillLevel += 1;
      }
      
      skillTree.lastUpdated = new Date();
      await skillTree.save();
      
      return {
        skill: skillName,
        level: skill.level,
        xp: skill.xp,
        leveledUp,
        skillPoints: skillTree.skillPoints
      };
    } catch (error) {
      logger.error('Error awarding skill XP:', error);
      throw error;
    }
  }
}

export default new SkillTreeService();

