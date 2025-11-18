/**
 * Social Graph Service
 * Manages user connections and social features for multiplayer
 */
const mongoose = require('mongoose');
const logger = require('../utils/logger');

const SocialConnectionSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  connectedUserId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
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

// Compound index for efficient queries
SocialConnectionSchema.index({ userId: 1, connectedUserId: 1 }, { unique: true });

const SocialConnection = mongoose.model('SocialConnection', SocialConnectionSchema);

class SocialGraphService {
  /**
   * Send friend request
   */
  async sendFriendRequest(userId, targetUserId) {
    try {
      // Check if connection already exists
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

  /**
   * Accept friend request
   */
  async acceptFriendRequest(userId, requesterId) {
    try {
      const connection = await SocialConnection.findOne({
        userId: requesterId,
        connectedUserId: userId,
        status: 'pending'
      });

      if (!connection) {
        throw new Error('No pending request found');
      }

      connection.status = 'accepted';
      connection.updatedAt = new Date();
      await connection.save();

      // Create reverse connection
      const reverseConnection = await SocialConnection.findOne({
        userId,
        connectedUserId: requesterId
      });

      if (!reverseConnection) {
        const reverse = new SocialConnection({
          userId,
          connectedUserId: requesterId,
          connectionType: 'friend',
          status: 'accepted'
        });
        await reverse.save();
      } else {
        reverseConnection.status = 'accepted';
        await reverseConnection.save();
      }

      await this._updateMetadata(userId, requesterId);

      logger.info('Friend request accepted', { userId, requesterId });
      return connection;
    } catch (error) {
      logger.error('Error accepting friend request:', error);
      throw error;
    }
  }

  /**
   * Get user's connections
   */
  async getConnections(userId, connectionType = null, status = 'accepted') {
    try {
      const query = { userId, status };
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

  /**
   * Get mutual connections
   */
  async getMutualConnections(userId1, userId2) {
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

      const mutualConnections = await mongoose.model('User').find({
        _id: { $in: mutualIds }
      }).select('name email avatar');

      return mutualConnections;
    } catch (error) {
      logger.error('Error getting mutual connections:', error);
      throw error;
    }
  }

  /**
   * Get social graph statistics
   */
  async getSocialStats(userId) {
    try {
      const connections = await SocialConnection.find({ userId, status: 'accepted' });
      
      const stats = {
        totalConnections: connections.length,
        friends: connections.filter(c => c.connectionType === 'friend').length,
        followers: connections.filter(c => c.connectionType === 'follower').length,
        following: connections.filter(c => c.connectionType === 'following').length,
        teammates: connections.filter(c => c.connectionType === 'teammate').length,
        rivals: connections.filter(c => c.connectionType === 'rival').length,
        averageCollaborationScore: 0
      };

      const collaborationScores = connections
        .map(c => c.metadata?.collaborationScore || 0)
        .filter(score => score > 0);

      if (collaborationScores.length > 0) {
        stats.averageCollaborationScore = collaborationScores.reduce((a, b) => a + b, 0) / collaborationScores.length;
      }

      return stats;
    } catch (error) {
      logger.error('Error getting social stats:', error);
      throw error;
    }
  }

  /**
   * Follow user
   */
  async followUser(userId, targetUserId) {
    try {
      const connection = new SocialConnection({
        userId,
        connectedUserId: targetUserId,
        connectionType: 'following',
        status: 'accepted'
      });

      await connection.save();

      // Create reverse follower connection
      const followerConnection = new SocialConnection({
        userId: targetUserId,
        connectedUserId: userId,
        connectionType: 'follower',
        status: 'accepted'
      });

      await followerConnection.save();

      logger.info('User followed', { userId, targetUserId });
      return connection;
    } catch (error) {
      logger.error('Error following user:', error);
      throw error;
    }
  }

  /**
   * Block user
   */
  async blockUser(userId, targetUserId) {
    try {
      // Update or create blocked connection
      await SocialConnection.findOneAndUpdate(
        { userId, connectedUserId: targetUserId },
        { status: 'blocked', updatedAt: new Date() },
        { upsert: true }
      );

      // Remove any existing connections
      await SocialConnection.deleteMany({
        $or: [
          { userId, connectedUserId: targetUserId, status: { $ne: 'blocked' } },
          { userId: targetUserId, connectedUserId: userId, status: { $ne: 'blocked' } }
        ]
      });

      logger.info('User blocked', { userId, targetUserId });
      return { message: 'User blocked successfully' };
    } catch (error) {
      logger.error('Error blocking user:', error);
      throw error;
    }
  }

  /**
   * Update connection metadata
   */
  async _updateMetadata(userId1, userId2) {
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

  /**
   * Get recommended connections
   */
  async getRecommendedConnections(userId, limit = 10) {
    try {
      // Get user's current connections
      const userConnections = await SocialConnection.find({
        userId,
        status: 'accepted'
      }).select('connectedUserId');

      const connectedIds = userConnections.map(c => c.connectedUserId.toString());
      connectedIds.push(userId.toString());

      // Find users with mutual connections
      const recommendations = await SocialConnection.aggregate([
        {
          $match: {
            userId: { $in: userConnections.map(c => c.connectedUserId) },
            connectedUserId: { $nin: connectedIds.map(id => new mongoose.Types.ObjectId(id)) },
            status: 'accepted'
          }
        },
        {
          $group: {
            _id: '$connectedUserId',
            mutualCount: { $sum: 1 }
          }
        },
        { $sort: { mutualCount: -1 } },
        { $limit: limit }
      ]);

      const recommendedIds = recommendations.map(r => r._id);
      const recommendedUsers = await mongoose.model('User').find({
        _id: { $in: recommendedIds }
      }).select('name email avatar');

      return recommendedUsers.map(user => ({
        user,
        mutualConnections: recommendations.find(r => r._id.toString() === user._id.toString())?.mutualCount || 0
      }));
    } catch (error) {
      logger.error('Error getting recommended connections:', error);
      throw error;
    }
  }
}

module.exports = new SocialGraphService();

