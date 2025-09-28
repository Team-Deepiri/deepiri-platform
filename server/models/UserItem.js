const mongoose = require('mongoose');

const userItemSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  itemId: {
    type: String,
    required: true,
    trim: true
  },
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  description: {
    type: String,
    maxlength: 1000
  },
  category: {
    type: String,
    required: true,
    enum: [
      'adventure_gear', 'collectible', 'badge', 'achievement', 
      'souvenir', 'memory', 'photo', 'ticket', 'certificate',
      'virtual_item', 'reward', 'token', 'other'
    ],
    index: true
  },
  type: {
    type: String,
    required: true,
    enum: [
      'physical', 'digital', 'virtual', 'achievement', 
      'badge', 'token', 'memory', 'experience'
    ]
  },
  rarity: {
    type: String,
    enum: ['common', 'uncommon', 'rare', 'epic', 'legendary'],
    default: 'common'
  },
  value: {
    points: { type: Number, default: 0 },
    coins: { type: Number, default: 0 },
    monetaryValue: { type: Number, default: 0 },
    currency: { type: String, default: 'USD' }
  },
  properties: {
    color: String,
    size: String,
    weight: Number,
    material: String,
    brand: String,
    condition: {
      type: String,
      enum: ['new', 'excellent', 'good', 'fair', 'poor'],
      default: 'new'
    },
    customAttributes: [{
      key: String,
      value: mongoose.Schema.Types.Mixed
    }]
  },
  location: {
    source: {
      type: String,
      enum: ['adventure', 'event', 'purchase', 'gift', 'achievement', 'reward', 'other'],
      required: true
    },
    sourceId: String, // Adventure ID, Event ID, etc.
    sourceName: String,
    acquiredAt: {
      type: Date,
      default: Date.now
    },
    acquiredLocation: {
      lat: Number,
      lng: Number,
      address: String,
      venue: String
    }
  },
  media: {
    images: [{
      url: String,
      caption: String,
      isPrimary: { type: Boolean, default: false }
    }],
    videos: [{
      url: String,
      caption: String,
      thumbnail: String
    }],
    documents: [{
      url: String,
      name: String,
      type: String // pdf, doc, etc.
    }]
  },
  metadata: {
    tags: [String],
    isPublic: { type: Boolean, default: false },
    isFavorite: { type: Boolean, default: false },
    isArchived: { type: Boolean, default: false },
    notes: String,
    memories: [{
      title: String,
      description: String,
      date: Date,
      emotion: {
        type: String,
        enum: ['happy', 'excited', 'nostalgic', 'proud', 'grateful', 'adventurous']
      }
    }]
  },
  sharing: {
    isShared: { type: Boolean, default: false },
    sharedWith: [{
      userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      permission: {
        type: String,
        enum: ['view', 'comment', 'edit'],
        default: 'view'
      },
      sharedAt: { type: Date, default: Date.now }
    }],
    socialPosts: [{
      platform: String,
      postId: String,
      url: String,
      postedAt: Date
    }]
  },
  gamification: {
    experiencePoints: { type: Number, default: 0 },
    level: { type: Number, default: 1 },
    achievements: [String],
    streakDays: { type: Number, default: 0 },
    lastInteraction: Date
  },
  status: {
    type: String,
    enum: ['active', 'archived', 'deleted', 'lost', 'gifted'],
    default: 'active'
  }
}, {
  timestamps: true
});

// Indexes for better performance
userItemSchema.index({ userId: 1, category: 1 });
userItemSchema.index({ userId: 1, 'metadata.isFavorite': 1 });
userItemSchema.index({ userId: 1, status: 1 });
userItemSchema.index({ userId: 1, 'location.source': 1 });
userItemSchema.index({ 'metadata.tags': 1 });
userItemSchema.index({ createdAt: -1 });

// Virtual for item age
userItemSchema.virtual('ageInDays').get(function() {
  return Math.floor((Date.now() - this.location.acquiredAt.getTime()) / (1000 * 60 * 60 * 24));
});

// Method to get public item data
userItemSchema.methods.getPublicData = function() {
  const itemObject = this.toObject();
  
  // Remove sensitive data if not public
  if (!this.metadata.isPublic) {
    delete itemObject.value.monetaryValue;
    delete itemObject.sharing;
    delete itemObject.metadata.notes;
  }
  
  return itemObject;
};

// Method to add memory
userItemSchema.methods.addMemory = function(memoryData) {
  this.metadata.memories.push({
    title: memoryData.title,
    description: memoryData.description,
    date: memoryData.date || new Date(),
    emotion: memoryData.emotion
  });
  
  this.gamification.lastInteraction = new Date();
  return this.save();
};

// Method to update interaction
userItemSchema.methods.updateInteraction = function() {
  this.gamification.lastInteraction = new Date();
  
  // Update streak if interacted today
  const today = new Date();
  const lastInteraction = this.gamification.lastInteraction;
  
  if (lastInteraction) {
    const daysDiff = Math.floor((today - lastInteraction) / (1000 * 60 * 60 * 24));
    if (daysDiff === 1) {
      this.gamification.streakDays += 1;
    } else if (daysDiff > 1) {
      this.gamification.streakDays = 1;
    }
  } else {
    this.gamification.streakDays = 1;
  }
  
  return this.save();
};

// Static method to get user's item statistics
userItemSchema.statics.getUserItemStats = async function(userId) {
  const stats = await this.aggregate([
    { $match: { userId: new mongoose.Types.ObjectId(userId), status: 'active' } },
    {
      $group: {
        _id: null,
        totalItems: { $sum: 1 },
        totalValue: { $sum: '$value.points' },
        categories: { $addToSet: '$category' },
        rarityCount: {
          $push: '$rarity'
        },
        favoriteCount: {
          $sum: { $cond: ['$metadata.isFavorite', 1, 0] }
        }
      }
    }
  ]);
  
  return stats[0] || {
    totalItems: 0,
    totalValue: 0,
    categories: [],
    rarityCount: [],
    favoriteCount: 0
  };
};

// Static method to get items by category
userItemSchema.statics.getItemsByCategory = async function(userId, category, options = {}) {
  const query = { 
    userId: new mongoose.Types.ObjectId(userId), 
    status: 'active'
  };
  
  if (category && category !== 'all') {
    query.category = category;
  }
  
  const sort = options.sort || { createdAt: -1 };
  const limit = options.limit || 50;
  const skip = options.skip || 0;
  
  return this.find(query)
    .sort(sort)
    .limit(limit)
    .skip(skip)
    .lean();
};

module.exports = mongoose.model('UserItem', userItemSchema);
