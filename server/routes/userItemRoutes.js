const express = require('express');
const Joi = require('joi');
const userItemService = require('../services/userItemService');
const logger = require('../utils/logger');
const {
  verifyItemOwnership,
  verifySharedItemAccess,
  verifyEditPermission,
  validateUserId,
  itemRateLimit,
  auditItemOperation
} = require('../middleware/userItemAuth');

const router = express.Router();

// Apply user ID validation and rate limiting to all routes
router.use(validateUserId);
router.use(itemRateLimit(100, 15 * 60 * 1000)); // 100 requests per 15 minutes

// Validation schemas
const createItemSchema = Joi.object({
  name: Joi.string().min(1).max(200).required(),
  description: Joi.string().max(1000).optional(),
  category: Joi.string().valid(
    'adventure_gear', 'collectible', 'badge', 'achievement', 
    'souvenir', 'memory', 'photo', 'ticket', 'certificate',
    'virtual_item', 'reward', 'token', 'other'
  ).required(),
  type: Joi.string().valid(
    'physical', 'digital', 'virtual', 'achievement', 
    'badge', 'token', 'memory', 'experience'
  ).required(),
  rarity: Joi.string().valid('common', 'uncommon', 'rare', 'epic', 'legendary').optional(),
  value: Joi.object({
    points: Joi.number().min(0).optional(),
    coins: Joi.number().min(0).optional(),
    monetaryValue: Joi.number().min(0).optional(),
    currency: Joi.string().optional()
  }).optional(),
  properties: Joi.object({
    color: Joi.string().optional(),
    size: Joi.string().optional(),
    weight: Joi.number().optional(),
    material: Joi.string().optional(),
    brand: Joi.string().optional(),
    condition: Joi.string().valid('new', 'excellent', 'good', 'fair', 'poor').optional(),
    customAttributes: Joi.array().items(Joi.object({
      key: Joi.string().required(),
      value: Joi.any().required()
    })).optional()
  }).optional(),
  source: Joi.string().valid('adventure', 'event', 'purchase', 'gift', 'achievement', 'reward', 'other').optional(),
  sourceId: Joi.string().optional(),
  sourceName: Joi.string().optional(),
  acquiredAt: Joi.date().optional(),
  acquiredLocation: Joi.object({
    lat: Joi.number().optional(),
    lng: Joi.number().optional(),
    address: Joi.string().optional(),
    venue: Joi.string().optional()
  }).optional(),
  media: Joi.object({
    images: Joi.array().items(Joi.object({
      url: Joi.string().uri().required(),
      caption: Joi.string().optional(),
      isPrimary: Joi.boolean().optional()
    })).optional(),
    videos: Joi.array().items(Joi.object({
      url: Joi.string().uri().required(),
      caption: Joi.string().optional(),
      thumbnail: Joi.string().uri().optional()
    })).optional(),
    documents: Joi.array().items(Joi.object({
      url: Joi.string().uri().required(),
      name: Joi.string().required(),
      type: Joi.string().required()
    })).optional()
  }).optional(),
  tags: Joi.array().items(Joi.string()).optional(),
  isPublic: Joi.boolean().optional(),
  isFavorite: Joi.boolean().optional(),
  notes: Joi.string().optional()
});

const updateItemSchema = Joi.object({
  name: Joi.string().min(1).max(200).optional(),
  description: Joi.string().max(1000).optional(),
  rarity: Joi.string().valid('common', 'uncommon', 'rare', 'epic', 'legendary').optional(),
  value: Joi.object({
    points: Joi.number().min(0).optional(),
    coins: Joi.number().min(0).optional(),
    monetaryValue: Joi.number().min(0).optional(),
    currency: Joi.string().optional()
  }).optional(),
  properties: Joi.object({
    color: Joi.string().optional(),
    size: Joi.string().optional(),
    weight: Joi.number().optional(),
    material: Joi.string().optional(),
    brand: Joi.string().optional(),
    condition: Joi.string().valid('new', 'excellent', 'good', 'fair', 'poor').optional(),
    customAttributes: Joi.array().items(Joi.object({
      key: Joi.string().required(),
      value: Joi.any().required()
    })).optional()
  }).optional(),
  media: Joi.object({
    images: Joi.array().items(Joi.object({
      url: Joi.string().uri().required(),
      caption: Joi.string().optional(),
      isPrimary: Joi.boolean().optional()
    })).optional(),
    videos: Joi.array().items(Joi.object({
      url: Joi.string().uri().required(),
      caption: Joi.string().optional(),
      thumbnail: Joi.string().uri().optional()
    })).optional(),
    documents: Joi.array().items(Joi.object({
      url: Joi.string().uri().required(),
      name: Joi.string().required(),
      type: Joi.string().required()
    })).optional()
  }).optional(),
  metadata: Joi.object({
    tags: Joi.array().items(Joi.string()).optional(),
    isPublic: Joi.boolean().optional(),
    isFavorite: Joi.boolean().optional(),
    notes: Joi.string().optional()
  }).optional()
});

const addMemorySchema = Joi.object({
  title: Joi.string().min(1).max(100).required(),
  description: Joi.string().max(500).optional(),
  date: Joi.date().optional(),
  emotion: Joi.string().valid('happy', 'excited', 'nostalgic', 'proud', 'grateful', 'adventurous').optional()
});

const shareItemSchema = Joi.object({
  sharedWith: Joi.array().items(Joi.object({
    userId: Joi.string().required(),
    permission: Joi.string().valid('view', 'comment', 'edit').optional()
  })).optional(),
  isPublic: Joi.boolean().optional()
});

// Get all user items
router.get('/', auditItemOperation('list'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const {
      category = 'all',
      status = 'active',
      isFavorite,
      isPublic,
      tags,
      sort = 'createdAt',
      order = 'desc',
      limit = 50,
      page = 1
    } = req.query;

    const options = {
      category,
      status,
      limit: parseInt(limit),
      skip: (parseInt(page) - 1) * parseInt(limit),
      sort: { [sort]: order === 'desc' ? -1 : 1 }
    };

    if (isFavorite !== undefined) {
      options.isFavorite = isFavorite === 'true';
    }

    if (isPublic !== undefined) {
      options.isPublic = isPublic === 'true';
    }

    if (tags) {
      options.tags = Array.isArray(tags) ? tags : tags.split(',');
    }

    const items = await userItemService.getUserItems(userId, options);

    res.json({
      success: true,
      data: items,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: items.length
      }
    });

  } catch (error) {
    logger.error('Failed to get user items:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get user item statistics
router.get('/stats', auditItemOperation('stats'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const stats = await userItemService.getUserItemStats(userId);

    res.json({
      success: true,
      data: stats
    });

  } catch (error) {
    logger.error('Failed to get user item stats:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Search user items
router.get('/search', auditItemOperation('search'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { q: searchQuery, category, tags, limit = 20, page = 1 } = req.query;

    if (!searchQuery) {
      return res.status(400).json({
        success: false,
        message: 'Search query is required'
      });
    }

    const options = {
      category,
      limit: parseInt(limit),
      skip: (parseInt(page) - 1) * parseInt(limit)
    };

    if (tags) {
      options.tags = Array.isArray(tags) ? tags : tags.split(',');
    }

    const items = await userItemService.searchUserItems(userId, searchQuery, options);

    res.json({
      success: true,
      data: items,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Failed to search user items:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get shared items (items shared with current user)
router.get('/shared', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { limit = 20, page = 1 } = req.query;

    const options = {
      limit: parseInt(limit),
      skip: (parseInt(page) - 1) * parseInt(limit)
    };

    const items = await userItemService.getSharedItems(userId, options);

    res.json({
      success: true,
      data: items,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Failed to get shared items:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get public items (community items)
router.get('/public', async (req, res) => {
  try {
    const { category, limit = 50, page = 1, sort = 'createdAt', order = 'desc' } = req.query;

    const options = {
      category,
      limit: parseInt(limit),
      skip: (parseInt(page) - 1) * parseInt(limit),
      sort: { [sort]: order === 'desc' ? -1 : 1 }
    };

    const items = await userItemService.getPublicItems(options);

    res.json({
      success: true,
      data: items,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit)
      }
    });

  } catch (error) {
    logger.error('Failed to get public items:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Export user items
router.get('/export', auditItemOperation('export'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { format = 'json' } = req.query;

    const items = await userItemService.exportUserItems(userId, format);

    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=user_items.csv');
      res.send(items);
    } else {
      res.json({
        success: true,
        data: items
      });
    }

  } catch (error) {
    logger.error('Failed to export user items:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get specific user item
router.get('/:itemId', verifySharedItemAccess, auditItemOperation('view'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { itemId } = req.params;

    const item = await userItemService.getUserItemById(userId, itemId);

    res.json({
      success: true,
      data: item
    });

  } catch (error) {
    logger.error('Failed to get user item:', error);
    res.status(404).json({
      success: false,
      message: error.message
    });
  }
});

// Create new user item
router.post('/', auditItemOperation('create'), async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Validate request data
    const { error, value } = createItemSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.details.map(detail => detail.message)
      });
    }

    const item = await userItemService.createUserItem(userId, value);

    res.status(201).json({
      success: true,
      message: 'Item created successfully',
      data: item
    });

  } catch (error) {
    logger.error('Failed to create user item:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

// Bulk create user items
router.post('/bulk', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { items } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Items array is required and must not be empty'
      });
    }

    // Validate each item
    for (let i = 0; i < items.length; i++) {
      const { error } = createItemSchema.validate(items[i]);
      if (error) {
        return res.status(400).json({
          success: false,
          message: `Validation error in item ${i + 1}`,
          errors: error.details.map(detail => detail.message)
        });
      }
    }

    const createdItems = await userItemService.bulkCreateItems(userId, items);

    res.status(201).json({
      success: true,
      message: `${createdItems.length} items created successfully`,
      data: createdItems
    });

  } catch (error) {
    logger.error('Failed to bulk create user items:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

// Update user item
router.put('/:itemId', verifyItemOwnership, auditItemOperation('update'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { itemId } = req.params;
    
    // Validate request data
    const { error, value } = updateItemSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.details.map(detail => detail.message)
      });
    }

    const item = await userItemService.updateUserItem(userId, itemId, value);

    res.json({
      success: true,
      message: 'Item updated successfully',
      data: item
    });

  } catch (error) {
    logger.error('Failed to update user item:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

// Toggle item favorite status
router.patch('/:itemId/favorite', verifyItemOwnership, auditItemOperation('toggle_favorite'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { itemId } = req.params;

    const item = await userItemService.toggleFavorite(userId, itemId);

    res.json({
      success: true,
      message: `Item ${item.metadata.isFavorite ? 'added to' : 'removed from'} favorites`,
      data: { isFavorite: item.metadata.isFavorite }
    });

  } catch (error) {
    logger.error('Failed to toggle favorite:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

// Add memory to item
router.post('/:itemId/memories', verifyItemOwnership, auditItemOperation('add_memory'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { itemId } = req.params;
    
    // Validate request data
    const { error, value } = addMemorySchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.details.map(detail => detail.message)
      });
    }

    const item = await userItemService.addItemMemory(userId, itemId, value);

    res.json({
      success: true,
      message: 'Memory added successfully',
      data: item.metadata.memories
    });

  } catch (error) {
    logger.error('Failed to add memory:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

// Share item
router.post('/:itemId/share', verifyItemOwnership, auditItemOperation('share'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { itemId } = req.params;
    
    // Validate request data
    const { error, value } = shareItemSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.details.map(detail => detail.message)
      });
    }

    const item = await userItemService.shareItem(userId, itemId, value);

    res.json({
      success: true,
      message: 'Item shared successfully',
      data: item.sharing
    });

  } catch (error) {
    logger.error('Failed to share item:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

// Delete user item
router.delete('/:itemId', verifyItemOwnership, auditItemOperation('delete'), async (req, res) => {
  try {
    const userId = req.user.userId;
    const { itemId } = req.params;
    const { permanent = false } = req.query;

    await userItemService.deleteUserItem(userId, itemId, permanent === 'true');

    res.json({
      success: true,
      message: `Item ${permanent === 'true' ? 'permanently deleted' : 'moved to trash'}`
    });

  } catch (error) {
    logger.error('Failed to delete user item:', error);
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
