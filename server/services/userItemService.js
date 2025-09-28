const UserItem = require('../models/UserItem');
const User = require('../models/User');
const cacheService = require('./cacheService');
const logger = require('../utils/logger');

class UserItemService {
  async createUserItem(userId, itemData) {
    try {
      // Validate user exists
      const user = await User.findById(userId);
      if (!user) {
        throw new Error('User not found');
      }

      // Create new user item
      const userItem = new UserItem({
        userId,
        itemId: itemData.itemId || this.generateItemId(),
        name: itemData.name,
        description: itemData.description,
        category: itemData.category,
        type: itemData.type,
        rarity: itemData.rarity || 'common',
        value: itemData.value || { points: 0, coins: 0 },
        properties: itemData.properties || {},
        location: {
          source: itemData.source || 'other',
          sourceId: itemData.sourceId,
          sourceName: itemData.sourceName,
          acquiredAt: itemData.acquiredAt || new Date(),
          acquiredLocation: itemData.acquiredLocation
        },
        media: itemData.media || { images: [], videos: [], documents: [] },
        metadata: {
          tags: itemData.tags || [],
          isPublic: itemData.isPublic || false,
          isFavorite: itemData.isFavorite || false,
          notes: itemData.notes
        }
      });

      await userItem.save();

      // Clear user items cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`User item created: ${userItem.name} for user ${userId}`);
      return userItem;

    } catch (error) {
      logger.error('Failed to create user item:', error);
      throw new Error(`Failed to create user item: ${error.message}`);
    }
  }

  async getUserItems(userId, options = {}) {
    try {
      const {
        category = 'all',
        status = 'active',
        isFavorite,
        isPublic,
        tags,
        sort = { createdAt: -1 },
        limit = 50,
        skip = 0
      } = options;

      // Check cache first
      const cacheKey = `user_items:${userId}:${JSON.stringify(options)}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      // Build query
      const query = { userId, status };
      
      if (category && category !== 'all') {
        query.category = category;
      }
      
      if (isFavorite !== undefined) {
        query['metadata.isFavorite'] = isFavorite;
      }
      
      if (isPublic !== undefined) {
        query['metadata.isPublic'] = isPublic;
      }
      
      if (tags && tags.length > 0) {
        query['metadata.tags'] = { $in: tags };
      }

      const items = await UserItem.find(query)
        .sort(sort)
        .limit(limit)
        .skip(skip)
        .lean();

      // Cache results
      await cacheService.set(cacheKey, items, 1800); // 30 minutes

      return items;

    } catch (error) {
      logger.error('Failed to get user items:', error);
      throw new Error(`Failed to get user items: ${error.message}`);
    }
  }

  async getUserItemById(userId, itemId) {
    try {
      const item = await UserItem.findOne({ 
        _id: itemId, 
        userId, 
        status: { $ne: 'deleted' } 
      });
      
      if (!item) {
        throw new Error('Item not found');
      }

      return item;

    } catch (error) {
      logger.error('Failed to get user item:', error);
      throw new Error(`Failed to get user item: ${error.message}`);
    }
  }

  async updateUserItem(userId, itemId, updateData) {
    try {
      const item = await UserItem.findOne({ 
        _id: itemId, 
        userId, 
        status: { $ne: 'deleted' } 
      });
      
      if (!item) {
        throw new Error('Item not found');
      }

      // Update allowed fields
      const allowedFields = [
        'name', 'description', 'properties', 'metadata', 
        'media', 'value', 'rarity'
      ];
      
      for (const field of allowedFields) {
        if (updateData[field] !== undefined) {
          if (field === 'metadata') {
            item.metadata = { ...item.metadata, ...updateData[field] };
          } else if (field === 'properties') {
            item.properties = { ...item.properties, ...updateData[field] };
          } else if (field === 'media') {
            item.media = { ...item.media, ...updateData[field] };
          } else if (field === 'value') {
            item.value = { ...item.value, ...updateData[field] };
          } else {
            item[field] = updateData[field];
          }
        }
      }

      item.updatedAt = new Date();
      await item.save();

      // Clear cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`User item ${itemId} updated for user ${userId}`);
      return item;

    } catch (error) {
      logger.error('Failed to update user item:', error);
      throw new Error(`Failed to update user item: ${error.message}`);
    }
  }

  async deleteUserItem(userId, itemId, permanent = false) {
    try {
      const item = await UserItem.findOne({ 
        _id: itemId, 
        userId, 
        status: { $ne: 'deleted' } 
      });
      
      if (!item) {
        throw new Error('Item not found');
      }

      if (permanent) {
        await UserItem.findByIdAndDelete(itemId);
      } else {
        item.status = 'deleted';
        item.updatedAt = new Date();
        await item.save();
      }

      // Clear cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`User item ${itemId} ${permanent ? 'permanently deleted' : 'soft deleted'} for user ${userId}`);
      return true;

    } catch (error) {
      logger.error('Failed to delete user item:', error);
      throw new Error(`Failed to delete user item: ${error.message}`);
    }
  }

  async addItemMemory(userId, itemId, memoryData) {
    try {
      const item = await this.getUserItemById(userId, itemId);
      
      await item.addMemory(memoryData);
      
      // Clear cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`Memory added to item ${itemId} for user ${userId}`);
      return item;

    } catch (error) {
      logger.error('Failed to add item memory:', error);
      throw new Error(`Failed to add item memory: ${error.message}`);
    }
  }

  async toggleFavorite(userId, itemId) {
    try {
      const item = await this.getUserItemById(userId, itemId);
      
      item.metadata.isFavorite = !item.metadata.isFavorite;
      item.updatedAt = new Date();
      await item.save();

      // Clear cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`Item ${itemId} favorite toggled for user ${userId}`);
      return item;

    } catch (error) {
      logger.error('Failed to toggle favorite:', error);
      throw new Error(`Failed to toggle favorite: ${error.message}`);
    }
  }

  async shareItem(userId, itemId, shareData) {
    try {
      const item = await this.getUserItemById(userId, itemId);
      
      // Validate share recipients
      if (shareData.sharedWith && shareData.sharedWith.length > 0) {
        for (const share of shareData.sharedWith) {
          const recipient = await User.findById(share.userId);
          if (!recipient) {
            throw new Error(`User ${share.userId} not found`);
          }
        }
      }

      item.sharing.isShared = true;
      item.sharing.sharedWith = shareData.sharedWith || [];
      item.metadata.isPublic = shareData.isPublic || false;
      item.updatedAt = new Date();
      
      await item.save();

      // Clear cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`Item ${itemId} shared by user ${userId}`);
      return item;

    } catch (error) {
      logger.error('Failed to share item:', error);
      throw new Error(`Failed to share item: ${error.message}`);
    }
  }

  async getUserItemStats(userId) {
    try {
      // Check cache first
      const cacheKey = `user_item_stats:${userId}`;
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return cached;
      }

      const stats = await UserItem.getUserItemStats(userId);
      
      // Get additional stats
      const [
        recentItems,
        favoriteItems,
        categoryStats,
        rarityStats
      ] = await Promise.all([
        this.getUserItems(userId, { limit: 5, sort: { createdAt: -1 } }),
        this.getUserItems(userId, { isFavorite: true, limit: 10 }),
        this.getCategoryStats(userId),
        this.getRarityStats(userId)
      ]);

      const fullStats = {
        ...stats,
        recentItems,
        favoriteItems,
        categoryStats,
        rarityStats,
        lastUpdated: new Date()
      };

      // Cache stats
      await cacheService.set(cacheKey, fullStats, 3600); // 1 hour

      return fullStats;

    } catch (error) {
      logger.error('Failed to get user item stats:', error);
      throw new Error(`Failed to get user item stats: ${error.message}`);
    }
  }

  async getCategoryStats(userId) {
    try {
      const stats = await UserItem.aggregate([
        { $match: { userId: userId, status: 'active' } },
        {
          $group: {
            _id: '$category',
            count: { $sum: 1 },
            totalValue: { $sum: '$value.points' },
            avgValue: { $avg: '$value.points' },
            favorites: { $sum: { $cond: ['$metadata.isFavorite', 1, 0] } }
          }
        },
        { $sort: { count: -1 } }
      ]);

      return stats;

    } catch (error) {
      logger.error('Failed to get category stats:', error);
      return [];
    }
  }

  async getRarityStats(userId) {
    try {
      const stats = await UserItem.aggregate([
        { $match: { userId: userId, status: 'active' } },
        {
          $group: {
            _id: '$rarity',
            count: { $sum: 1 },
            totalValue: { $sum: '$value.points' }
          }
        },
        { $sort: { totalValue: -1 } }
      ]);

      return stats;

    } catch (error) {
      logger.error('Failed to get rarity stats:', error);
      return [];
    }
  }

  async searchUserItems(userId, searchQuery, options = {}) {
    try {
      const {
        category,
        tags,
        limit = 20,
        skip = 0
      } = options;

      const query = {
        userId,
        status: 'active',
        $or: [
          { name: { $regex: searchQuery, $options: 'i' } },
          { description: { $regex: searchQuery, $options: 'i' } },
          { 'metadata.tags': { $regex: searchQuery, $options: 'i' } }
        ]
      };

      if (category) {
        query.category = category;
      }

      if (tags && tags.length > 0) {
        query['metadata.tags'] = { $in: tags };
      }

      const items = await UserItem.find(query)
        .sort({ createdAt: -1 })
        .limit(limit)
        .skip(skip)
        .lean();

      return items;

    } catch (error) {
      logger.error('Failed to search user items:', error);
      throw new Error(`Failed to search user items: ${error.message}`);
    }
  }

  async getSharedItems(userId, options = {}) {
    try {
      const { limit = 20, skip = 0 } = options;

      // Get items shared with this user
      const sharedItems = await UserItem.find({
        'sharing.sharedWith.userId': userId,
        status: 'active'
      })
      .populate('userId', 'name profilePicture')
      .sort({ 'sharing.sharedWith.sharedAt': -1 })
      .limit(limit)
      .skip(skip)
      .lean();

      return sharedItems;

    } catch (error) {
      logger.error('Failed to get shared items:', error);
      throw new Error(`Failed to get shared items: ${error.message}`);
    }
  }

  async getPublicItems(options = {}) {
    try {
      const { 
        category,
        limit = 50,
        skip = 0,
        sort = { createdAt: -1 }
      } = options;

      const query = {
        'metadata.isPublic': true,
        status: 'active'
      };

      if (category && category !== 'all') {
        query.category = category;
      }

      const items = await UserItem.find(query)
        .populate('userId', 'name profilePicture')
        .sort(sort)
        .limit(limit)
        .skip(skip)
        .lean();

      return items;

    } catch (error) {
      logger.error('Failed to get public items:', error);
      throw new Error(`Failed to get public items: ${error.message}`);
    }
  }

  generateItemId() {
    return `item_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // Bulk operations
  async bulkCreateItems(userId, itemsData) {
    try {
      const items = itemsData.map(itemData => ({
        userId,
        itemId: itemData.itemId || this.generateItemId(),
        ...itemData,
        location: {
          source: itemData.source || 'bulk_import',
          acquiredAt: itemData.acquiredAt || new Date(),
          ...itemData.location
        }
      }));

      const createdItems = await UserItem.insertMany(items);

      // Clear cache
      await cacheService.clearUserItemsCache(userId);

      logger.info(`Bulk created ${createdItems.length} items for user ${userId}`);
      return createdItems;

    } catch (error) {
      logger.error('Failed to bulk create items:', error);
      throw new Error(`Failed to bulk create items: ${error.message}`);
    }
  }

  async exportUserItems(userId, format = 'json') {
    try {
      const items = await UserItem.find({ 
        userId, 
        status: { $ne: 'deleted' } 
      }).lean();

      if (format === 'csv') {
        // Convert to CSV format
        const csv = this.convertToCSV(items);
        return csv;
      }

      return items;

    } catch (error) {
      logger.error('Failed to export user items:', error);
      throw new Error(`Failed to export user items: ${error.message}`);
    }
  }

  convertToCSV(items) {
    if (items.length === 0) return '';

    const headers = [
      'name', 'description', 'category', 'type', 'rarity',
      'points', 'coins', 'source', 'acquiredAt', 'tags'
    ];

    const csvRows = [headers.join(',')];

    items.forEach(item => {
      const row = [
        `"${item.name}"`,
        `"${item.description || ''}"`,
        item.category,
        item.type,
        item.rarity,
        item.value.points || 0,
        item.value.coins || 0,
        item.location.source,
        item.location.acquiredAt.toISOString(),
        `"${(item.metadata.tags || []).join(';')}"`
      ];
      csvRows.push(row.join(','));
    });

    return csvRows.join('\n');
  }
}

module.exports = new UserItemService();
