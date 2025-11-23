import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('multi-currency-service');

type CurrencyType = 'xp' | 'coins' | 'gems' | 'energy' | 'tokens' | 'stars';
type TransactionType = 'earn' | 'spend' | 'reward' | 'purchase' | 'refund' | 'transfer';

interface ICurrencyBalance extends Document {
  userId: Types.ObjectId;
  currencies: {
    xp: number;
    coins: number;
    gems: number;
    energy: number;
    tokens: number;
    stars: number;
  };
  totalEarned: {
    xp: number;
    coins: number;
    gems: number;
  };
  lastUpdated: Date;
}

interface ICurrencyTransaction extends Document {
  userId: Types.ObjectId;
  currencyType: CurrencyType;
  amount: number;
  transactionType: TransactionType;
  source?: string;
  sourceId?: Types.ObjectId;
  description?: string;
  metadata?: Record<string, any>;
  createdAt: Date;
}

const CurrencyBalanceSchema = new Schema<ICurrencyBalance>({
  userId: { type: Schema.Types.ObjectId, required: true, unique: true, index: true },
  currencies: {
    xp: { type: Number, default: 0 },
    coins: { type: Number, default: 0 },
    gems: { type: Number, default: 0 },
    energy: { type: Number, default: 100, max: 100 },
    tokens: { type: Number, default: 0 },
    stars: { type: Number, default: 0 }
  },
  totalEarned: {
    xp: { type: Number, default: 0 },
    coins: { type: Number, default: 0 },
    gems: { type: Number, default: 0 }
  },
  lastUpdated: { type: Date, default: Date.now }
}, {
  timestamps: true
});

const CurrencyTransactionSchema = new Schema<ICurrencyTransaction>({
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  currencyType: {
    type: String,
    enum: ['xp', 'coins', 'gems', 'energy', 'tokens', 'stars'],
    required: true
  },
  amount: { type: Number, required: true },
  transactionType: {
    type: String,
    enum: ['earn', 'spend', 'reward', 'purchase', 'refund', 'transfer'],
    required: true
  },
  source: { type: String },
  sourceId: { type: Schema.Types.ObjectId },
  description: { type: String },
  metadata: Schema.Types.Mixed,
  createdAt: { type: Date, default: Date.now, index: true }
}, {
  timestamps: false
});

CurrencyTransactionSchema.index({ userId: 1, createdAt: -1 });

const CurrencyBalance: Model<ICurrencyBalance> = mongoose.model<ICurrencyBalance>('CurrencyBalance', CurrencyBalanceSchema);
const CurrencyTransaction: Model<ICurrencyTransaction> = mongoose.model<ICurrencyTransaction>('CurrencyTransaction', CurrencyTransactionSchema);

class MultiCurrencyService {
  private readonly CURRENCIES: CurrencyType[] = ['xp', 'coins', 'gems', 'energy', 'tokens', 'stars'];
  private readonly MAX_ENERGY = 100;
  private readonly ENERGY_REGENERATION_RATE = 1;

  async awardPoints(req: Request, res: Response): Promise<void> {
    try {
      const { userId, currencyType, amount, source, sourceId, description } = req.body;
      
      if (!userId || !currencyType || amount === undefined) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const result = await this.awardCurrency(
        new Types.ObjectId(userId),
        currencyType,
        amount,
        source,
        sourceId ? new Types.ObjectId(sourceId) : null,
        description
      );
      res.json(result);
    } catch (error: any) {
      logger.error('Error awarding points:', error);
      res.status(500).json({ error: error.message || 'Failed to award points' });
    }
  }

  async getBalance(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const balance = await this.getBalanceForUser(new Types.ObjectId(userId));
      res.json(balance);
    } catch (error: any) {
      logger.error('Error getting balance:', error);
      res.status(500).json({ error: 'Failed to get balance' });
    }
  }

  private async getOrCreateBalance(userId: Types.ObjectId): Promise<ICurrencyBalance> {
    try {
      let balance = await CurrencyBalance.findOne({ userId });
      
      if (!balance) {
        balance = new CurrencyBalance({ userId });
        await balance.save();
      }
      
      return balance;
    } catch (error) {
      logger.error('Error getting currency balance:', error);
      throw error;
    }
  }

  private async awardCurrency(
    userId: Types.ObjectId,
    currencyType: CurrencyType,
    amount: number,
    source: string | null = null,
    sourceId: Types.ObjectId | null = null,
    description: string | null = null
  ) {
    try {
      if (!this.CURRENCIES.includes(currencyType)) {
        throw new Error(`Invalid currency type: ${currencyType}`);
      }

      const balance = await this.getOrCreateBalance(userId);
      
      balance.currencies[currencyType] = (balance.currencies[currencyType] || 0) + amount;
      
      if (currencyType === 'energy') {
        balance.currencies.energy = Math.min(balance.currencies.energy, this.MAX_ENERGY);
      }

      if (amount > 0 && (currencyType === 'xp' || currencyType === 'coins' || currencyType === 'gems')) {
        balance.totalEarned[currencyType] = (balance.totalEarned[currencyType] || 0) + amount;
      }

      balance.lastUpdated = new Date();
      await balance.save();

      const transaction = new CurrencyTransaction({
        userId,
        currencyType,
        amount,
        transactionType: amount > 0 ? 'earn' : 'spend',
        source: source || undefined,
        sourceId: sourceId || undefined,
        description: description || `Awarded ${amount} ${currencyType}`
      });

      await transaction.save();

      logger.info('Currency awarded', { userId, currencyType, amount, source });
      
      return {
        currencyType,
        newBalance: balance.currencies[currencyType],
        totalEarned: (currencyType === 'xp' || currencyType === 'coins' || currencyType === 'gems') 
          ? (balance.totalEarned[currencyType] || 0)
          : 0
      };
    } catch (error) {
      logger.error('Error awarding currency:', error);
      throw error;
    }
  }

  private async spendCurrency(userId: Types.ObjectId, currencyType: CurrencyType, amount: number, description: string | null = null) {
    try {
      const balance = await this.getOrCreateBalance(userId);
      
      if (balance.currencies[currencyType] < amount) {
        throw new Error(`Insufficient ${currencyType}. Current: ${balance.currencies[currencyType]}, Required: ${amount}`);
      }

      balance.currencies[currencyType] -= amount;
      balance.lastUpdated = new Date();
      await balance.save();

      const transaction = new CurrencyTransaction({
        userId,
        currencyType,
        amount: -amount,
        transactionType: 'spend',
        description: description || `Spent ${amount} ${currencyType}`
      });

      await transaction.save();

      logger.info('Currency spent', { userId, currencyType, amount });
      
      return {
        currencyType,
        newBalance: balance.currencies[currencyType],
        spent: amount
      };
    } catch (error) {
      logger.error('Error spending currency:', error);
      throw error;
    }
  }

  private async getBalanceForUser(userId: Types.ObjectId) {
    try {
      const balance = await this.getOrCreateBalance(userId);
      return balance.currencies;
    } catch (error) {
      logger.error('Error getting balance:', error);
      throw error;
    }
  }
}

export default new MultiCurrencyService();

