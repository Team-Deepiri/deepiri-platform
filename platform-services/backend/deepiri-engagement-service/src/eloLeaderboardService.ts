import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('elo-leaderboard-service');

type Category = 'overall' | 'coding' | 'creative' | 'study' | 'productivity' | 'social';
type MatchResult = 'win' | 'loss' | 'draw' | 1.0 | 0.5 | 0.0;

interface IELORating extends Document {
  userId: Types.ObjectId;
  rating: number;
  peakRating: number;
  wins: number;
  losses: number;
  draws: number;
  totalMatches: number;
  winStreak: number;
  bestWinStreak: number;
  category: Category;
  lastUpdated: Date;
}

const ELORatingSchema = new Schema<IELORating>({
  userId: { type: Schema.Types.ObjectId, required: true, unique: true, index: true },
  rating: { type: Number, default: 1500, index: true },
  peakRating: { type: Number, default: 1500 },
  wins: { type: Number, default: 0 },
  losses: { type: Number, default: 0 },
  draws: { type: Number, default: 0 },
  totalMatches: { type: Number, default: 0 },
  winStreak: { type: Number, default: 0 },
  bestWinStreak: { type: Number, default: 0 },
  category: { type: String, default: 'overall', index: true },
  lastUpdated: { type: Date, default: Date.now }
}, {
  timestamps: true
});

ELORatingSchema.index({ category: 1, rating: -1 });
ELORatingSchema.index({ userId: 1, category: 1 }, { unique: true });

const ELORating: Model<IELORating> = mongoose.model<IELORating>('ELORating', ELORatingSchema);

class ELOLeaderboardService {
  private readonly K_FACTOR = 32;
  private readonly INITIAL_RATING = 1500;
  private readonly CATEGORIES: Category[] = ['overall', 'coding', 'creative', 'study', 'productivity', 'social'];

  async getLeaderboard(req: Request, res: Response): Promise<void> {
    try {
      const { category = 'overall', limit = 100, offset = 0 } = req.query;
      const leaderboard = await this.getLeaderboardData(
        category as Category,
        parseInt(limit as string, 10),
        parseInt(offset as string, 10)
      );
      res.json(leaderboard);
    } catch (error: any) {
      logger.error('Error getting leaderboard:', error);
      res.status(500).json({ error: 'Failed to get leaderboard' });
    }
  }

  async updateRating(req: Request, res: Response): Promise<void> {
    try {
      const { userId1, userId2, result, category = 'overall' } = req.body;
      
      if (!userId1 || !userId2 || result === undefined) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const updateResult = await this.updateRatings(
        new Types.ObjectId(userId1),
        new Types.ObjectId(userId2),
        result,
        category as Category
      );
      res.json(updateResult);
    } catch (error: any) {
      logger.error('Error updating rating:', error);
      res.status(500).json({ error: 'Failed to update rating' });
    }
  }

  private async getOrCreateRating(userId: Types.ObjectId, category: Category = 'overall'): Promise<IELORating> {
    try {
      let rating = await ELORating.findOne({ userId, category });
      
      if (!rating) {
        rating = new ELORating({
          userId,
          category,
          rating: this.INITIAL_RATING,
          peakRating: this.INITIAL_RATING
        });
        await rating.save();
      }
      
      return rating;
    } catch (error) {
      logger.error('Error getting ELO rating:', error);
      throw error;
    }
  }

  private _calculateExpectedScore(ratingA: number, ratingB: number): number {
    return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
  }

  private async updateRatings(userId1: Types.ObjectId, userId2: Types.ObjectId, result: MatchResult, category: Category = 'overall') {
    try {
      const rating1 = await this.getOrCreateRating(userId1, category);
      const rating2 = await this.getOrCreateRating(userId2, category);

      const expectedScore1 = this._calculateExpectedScore(rating1.rating, rating2.rating);
      const expectedScore2 = this._calculateExpectedScore(rating2.rating, rating1.rating);

      let score1: number, score2: number;
      if (result === 'win' || result === 1.0) {
        score1 = 1.0;
        score2 = 0.0;
      } else if (result === 'loss' || result === 0.0) {
        score1 = 0.0;
        score2 = 1.0;
      } else {
        score1 = 0.5;
        score2 = 0.5;
      }

      const newRating1 = rating1.rating + this.K_FACTOR * (score1 - expectedScore1);
      const newRating2 = rating2.rating + this.K_FACTOR * (score2 - expectedScore2);

      rating1.rating = Math.round(newRating1);
      rating1.peakRating = Math.max(rating1.peakRating, rating1.rating);
      rating1.totalMatches += 1;
      
      if (score1 > score2) {
        rating1.wins += 1;
        rating1.winStreak += 1;
        rating1.bestWinStreak = Math.max(rating1.bestWinStreak, rating1.winStreak);
      } else if (score1 < score2) {
        rating1.losses += 1;
        rating1.winStreak = 0;
      } else {
        rating1.draws += 1;
      }

      rating2.rating = Math.round(newRating2);
      rating2.peakRating = Math.max(rating2.peakRating, rating2.rating);
      rating2.totalMatches += 1;
      
      if (score2 > score1) {
        rating2.wins += 1;
        rating2.winStreak += 1;
        rating2.bestWinStreak = Math.max(rating2.bestWinStreak, rating2.winStreak);
      } else if (score2 < score1) {
        rating2.losses += 1;
        rating2.winStreak = 0;
      } else {
        rating2.draws += 1;
      }

      rating1.lastUpdated = new Date();
      rating2.lastUpdated = new Date();

      await rating1.save();
      await rating2.save();

      logger.info('ELO ratings updated', {
        userId1,
        userId2,
        category,
        newRating1: rating1.rating,
        newRating2: rating2.rating
      });

      return {
        user1: {
          userId: userId1,
          newRating: rating1.rating,
          change: Math.round(this.K_FACTOR * (score1 - expectedScore1))
        },
        user2: {
          userId: userId2,
          newRating: rating2.rating,
          change: Math.round(this.K_FACTOR * (score2 - expectedScore2))
        }
      };
    } catch (error) {
      logger.error('Error updating ELO ratings:', error);
      throw error;
    }
  }

  private async getLeaderboardData(category: Category = 'overall', limit: number = 100, offset: number = 0) {
    try {
      const ratings = await ELORating.find({ category })
        .populate('userId', 'name email avatar')
        .sort({ rating: -1 })
        .skip(offset)
        .limit(limit)
        .select('userId rating peakRating wins losses draws totalMatches winStreak bestWinStreak');

      const leaderboard = ratings.map((rating, index) => ({
        rank: offset + index + 1,
        user: rating.userId,
        rating: rating.rating,
        peakRating: rating.peakRating,
        wins: rating.wins,
        losses: rating.losses,
        draws: rating.draws,
        winRate: rating.totalMatches > 0 ? (rating.wins / rating.totalMatches) * 100 : 0,
        winStreak: rating.winStreak,
        bestWinStreak: rating.bestWinStreak
      }));

      return leaderboard;
    } catch (error) {
      logger.error('Error getting leaderboard:', error);
      throw error;
    }
  }
}

export default new ELOLeaderboardService();

