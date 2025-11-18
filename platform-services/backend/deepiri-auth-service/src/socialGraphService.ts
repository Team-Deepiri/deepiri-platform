import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('social-graph-service');

type ConnectionType = 'friend' | 'follower' | 'following' | 'teammate' | 'rival';
type ConnectionStatus = 'pending' | 'accepted' | 'blocked';

interface ISocialConnection extends Document {
  userId: Types.ObjectId;
  connectedUserId: Types.ObjectId;
  connectionType: ConnectionType;
  status: ConnectionStatus;
  metadata: {
    mutualConnections?: number;
    sharedChallenges?: number;
    collaborationScore?: number;
  };
  createdAt: Date;
  updatedAt: Date;
}

const SocialConnectionSchema = new Schema<ISocialConnection>({
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  connectedUserId: { type: Schema.Types.ObjectId, required: true, index: true },
  connectionType: { 
    type: String, 
    enum: ['friend', 'follower', 'following', 'teammate', 'rival'],
    default: 'friend'
  },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'blocked'],
    default: 'pending'
  },
  metadata: {
    mutualConnections: Number,
    sharedChallenges: Number,
    collaborationScore: Number
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, {
  timestamps: true
});

SocialConnectionSchema.index({ userId: 1, connectedUserId: 1 }, { unique: true });

const SocialConnection: Model<ISocialConnection> = mongoose.model<ISocialConnection>('SocialConnection', SocialConnectionSchema);

class SocialGraphService {
  async getFriends(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const connections = await this.getConnections(
        new Types.ObjectId(userId),
        'friend',
        'accepted'
      );
      res.json(connections);
    } catch (error) {
      logger.error('Error getting friends:', error);
      res.status(500).json({ error: 'Failed to get friends' });
    }
  }

  async addFriend(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { targetUserId } = req.body;
      
      if (!targetUserId) {
        res.status(400).json({ error: 'Missing targetUserId' });
        return;
      }

      const connection = await this.sendFriendRequest(
        new Types.ObjectId(userId),
        new Types.ObjectId(targetUserId)
      );
      res.json(connection);
    } catch (error) {
      logger.error('Error adding friend:', error);
      res.status(500).json({ error: 'Failed to add friend' });
    }
  }

  async sendFriendRequest(userId: Types.ObjectId, targetUserId: Types.ObjectId) {
    try {
      const existing = await SocialConnection.findOne({
        $or: [
          { userId, connectedUserId: targetUserId },
          { userId: targetUserId, connectedUserId: userId }
        ]
      });

      if (existing) {
        if (existing.status === 'blocked') {
          throw new Error('Cannot send request to blocked user');
        }
        if (existing.status === 'accepted') {
          return { message: 'Already connected', connection: existing };
        }
        return { message: 'Request already pending', connection: existing };
      }

      const connection = new SocialConnection({
        userId,
        connectedUserId: targetUserId,
        connectionType: 'friend',
        status: 'pending'
      });

      await connection.save();
      await this._updateMetadata(userId, targetUserId);

      logger.info('Friend request sent', { userId, targetUserId });
      return connection;
    } catch (error) {
      logger.error('Error sending friend request:', error);
      throw error;
    }
  }

  private async getConnections(userId: Types.ObjectId, connectionType: ConnectionType | null = null, status: ConnectionStatus = 'accepted') {
    try {
      const query: any = { userId, status };
      if (connectionType) {
        query.connectionType = connectionType;
      }

      const connections = await SocialConnection.find(query)
        .populate('connectedUserId', 'name email avatar')
        .sort({ updatedAt: -1 });

      return connections.map(conn => ({
        user: conn.connectedUserId,
        connectionType: conn.connectionType,
        metadata: conn.metadata,
        connectedAt: conn.createdAt
      }));
    } catch (error) {
      logger.error('Error getting connections:', error);
      throw error;
    }
  }

  private async _updateMetadata(userId1: Types.ObjectId, userId2: Types.ObjectId): Promise<void> {
    try {
      const mutual = await this.getMutualConnections(userId1, userId2);
      
      await SocialConnection.updateMany(
        {
          $or: [
            { userId: userId1, connectedUserId: userId2 },
            { userId: userId2, connectedUserId: userId1 }
          ]
        },
        {
          $set: {
            'metadata.mutualConnections': mutual.length
          }
        }
      );
    } catch (error) {
      logger.error('Error updating metadata:', error);
    }
  }

  private async getMutualConnections(userId1: Types.ObjectId, userId2: Types.ObjectId) {
    try {
      const user1Connections = await SocialConnection.find({
        userId: userId1,
        status: 'accepted'
      }).select('connectedUserId');

      const user2Connections = await SocialConnection.find({
        userId: userId2,
        status: 'accepted'
      }).select('connectedUserId');

      const user1Ids = new Set(user1Connections.map(c => c.connectedUserId.toString()));
      const user2Ids = new Set(user2Connections.map(c => c.connectedUserId.toString()));

      const mutualIds = [...user1Ids].filter(id => user2Ids.has(id));

      const User = mongoose.model('User');
      const mutualConnections = await User.find({
        _id: { $in: mutualIds }
      }).select('name email avatar');

      return mutualConnections;
    } catch (error) {
      logger.error('Error getting mutual connections:', error);
      throw error;
    }
  }
}

export default new SocialGraphService();

