/**
 * Skill Tree Service
 * Manages 20+ productivity skills with progression tracking
 */
const mongoose = require('mongoose');
const logger = require('../utils/logger');

const SkillTreeSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, unique: true },
  skills: {
    // Core Productivity Skills
    timeManagement: { level: Number, xp: Number, unlocked: Boolean },
    taskOrganization: { level: Number, xp: Number, unlocked: Boolean },
    focus: { level: Number, xp: Number, unlocked: Boolean },
    planning: { level: Number, xp: Number, unlocked: Boolean },
    
    // Technical Skills
    coding: { level: Number, xp: Number, unlocked: Boolean },
    debugging: { level: Number, xp: Number, unlocked: Boolean },
    codeReview: { level: Number, xp: Number, unlocked: Boolean },
    architecture: { level: Number, xp: Number, unlocked: Boolean },
    
    // Creative Skills
    writing: { level: Number, xp: Number, unlocked: Boolean },
    design: { level: Number, xp: Number, unlocked: Boolean },
    ideation: { level: Number, xp: Number, unlocked: Boolean },
    storytelling: { level: Number, xp: Number, unlocked: Boolean },
    
    // Learning Skills
    research: { level: Number, xp: Number, unlocked: Boolean },
    learning: { level: Number, xp: Number, unlocked: Boolean },
    noteTaking: { level: Number, xp: Number, unlocked: Boolean },
    knowledgeRetention: { level: Number, xp: Number, unlocked: Boolean },
    
    // Social Skills
    collaboration: { level: Number, xp: Number, unlocked: Boolean },
    communication: { level: Number, xp: Number, unlocked: Boolean },
    leadership: { level: Number, xp: Number, unlocked: Boolean },
    mentoring: { level: Number, xp: Number, unlocked: Boolean },
    
    // Meta Skills
    selfAwareness: { level: Number, xp: Number, unlocked: Boolean },
    adaptability: { level: Number, xp: Number, unlocked: Boolean }
  },
  skillPoints: { type: Number, default: 0 },
  totalSkillLevel: { type: Number, default: 0 },
  lastUpdated: { type: Date, default: Date.now }
}, { timestamps: true });

const SkillTree = mongoose.model('SkillTree', SkillTreeSchema);

class SkillTreeService {
  constructor() {
    this.SKILLS = [
      'timeManagement', 'taskOrganization', 'focus', 'planning',
      'coding', 'debugging', 'codeReview', 'architecture',
      'writing', 'design', 'ideation', 'storytelling',
      'research', 'learning', 'noteTaking', 'knowledgeRetention',
      'collaboration', 'communication', 'leadership', 'mentoring',
      'selfAwareness', 'adaptability'
    ];
    
    this.XP_PER_LEVEL = 1000;
    this.MAX_LEVEL = 100;
  }

  async getOrCreateSkillTree(userId) {
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

  _initializeSkills() {
    const skills = {};
    this.SKILLS.forEach(skill => {
      skills[skill] = {
        level: 1,
        xp: 0,
        unlocked: true
      };
    });
    return skills;
  }

  async awardSkillXP(userId, skillName, xpAmount) {
    try {
      const skillTree = await this.getOrCreateSkillTree(userId);
      
      if (!skillTree.skills[skillName]) {
        throw new Error(`Invalid skill: ${skillName}`);
      }
      
      const skill = skillTree.skills[skillName];
      skill.xp += xpAmount;
      
      // Check for level up
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

  async getSkillLevel(userId, skillName) {
    try {
      const skillTree = await this.getOrCreateSkillTree(userId);
      return skillTree.skills[skillName] || { level: 1, xp: 0, unlocked: false };
    } catch (error) {
      logger.error('Error getting skill level:', error);
      throw error;
    }
  }

  async getAllSkills(userId) {
    try {
      const skillTree = await this.getOrCreateSkillTree(userId);
      return skillTree.skills;
    } catch (error) {
      logger.error('Error getting all skills:', error);
      throw error;
    }
  }

  async unlockSkill(userId, skillName) {
    try {
      const skillTree = await this.getOrCreateSkillTree(userId);
      
      if (!skillTree.skills[skillName]) {
        throw new Error(`Invalid skill: ${skillName}`);
      }
      
      if (skillTree.skillPoints < 1) {
        throw new Error('Insufficient skill points');
      }
      
      if (skillTree.skills[skillName].unlocked) {
        return { message: 'Skill already unlocked' };
      }
      
      skillTree.skills[skillName].unlocked = true;
      skillTree.skillPoints -= 1;
      await skillTree.save();
      
      return { message: `Skill ${skillName} unlocked`, skillPoints: skillTree.skillPoints };
    } catch (error) {
      logger.error('Error unlocking skill:', error);
      throw error;
    }
  }

  async getSkillTreeProgress(userId) {
    try {
      const skillTree = await this.getOrCreateSkillTree(userId);
      const skills = skillTree.skills;
      
      const progress = {
        totalLevel: skillTree.totalSkillLevel,
        skillPoints: skillTree.skillPoints,
        skills: {},
        categories: {
          productivity: this._getCategoryProgress(skills, ['timeManagement', 'taskOrganization', 'focus', 'planning']),
          technical: this._getCategoryProgress(skills, ['coding', 'debugging', 'codeReview', 'architecture']),
          creative: this._getCategoryProgress(skills, ['writing', 'design', 'ideation', 'storytelling']),
          learning: this._getCategoryProgress(skills, ['research', 'learning', 'noteTaking', 'knowledgeRetention']),
          social: this._getCategoryProgress(skills, ['collaboration', 'communication', 'leadership', 'mentoring']),
          meta: this._getCategoryProgress(skills, ['selfAwareness', 'adaptability'])
        }
      };
      
      this.SKILLS.forEach(skillName => {
        progress.skills[skillName] = {
          level: skills[skillName].level,
          xp: skills[skillName].xp,
          xpToNext: this.XP_PER_LEVEL - (skills[skillName].xp % this.XP_PER_LEVEL),
          unlocked: skills[skillName].unlocked,
          progress: (skills[skillName].xp % this.XP_PER_LEVEL) / this.XP_PER_LEVEL
        };
      });
      
      return progress;
    } catch (error) {
      logger.error('Error getting skill tree progress:', error);
      throw error;
    }
  }

  _getCategoryProgress(skills, skillNames) {
    const totalLevel = skillNames.reduce((sum, name) => sum + (skills[name]?.level || 0), 0);
    const totalXP = skillNames.reduce((sum, name) => sum + (skills[name]?.xp || 0), 0);
    const unlocked = skillNames.filter(name => skills[name]?.unlocked).length;
    
    return {
      totalLevel,
      totalXP,
      unlocked,
      total: skillNames.length,
      averageLevel: totalLevel / skillNames.length
    };
  }
}

module.exports = new SkillTreeService();

