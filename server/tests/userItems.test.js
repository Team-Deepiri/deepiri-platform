const request = require('supertest');
const mongoose = require('mongoose');
const { app } = require('../server');
const User = require('../models/User');
const UserItem = require('../models/UserItem');
const userService = require('../services/userService');
const userItemService = require('../services/userItemService');

describe('User Items System', () => {
  let testUser;
  let authToken;
  let testItem;

  beforeAll(async () => {
    // Connect to test database
    const mongoUri = process.env.MONGODB_TEST_URI || 'mongodb://localhost:27017/tripblip_test';
    await mongoose.connect(mongoUri);
  });

  beforeEach(async () => {
    // Clean up database
    await User.deleteMany({});
    await UserItem.deleteMany({});

    // Create test user
    testUser = await userService.createUser({
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123'
    });

    // Generate auth token for testing
    const jwt = require('jsonwebtoken');
    authToken = jwt.sign(
      { userId: testUser._id, email: testUser.email },
      process.env.JWT_SECRET || 'test_secret',
      { expiresIn: '1h' }
    );
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  describe('UserItem Model', () => {
    test('should create a user item with required fields', async () => {
      const itemData = {
        userId: testUser._id,
        name: 'Test Adventure Badge',
        category: 'badge',
        type: 'achievement',
        location: {
          source: 'adventure',
          acquiredAt: new Date()
        }
      };

      const item = new UserItem(itemData);
      await item.save();

      expect(item.name).toBe('Test Adventure Badge');
      expect(item.category).toBe('badge');
      expect(item.type).toBe('achievement');
      expect(item.status).toBe('active');
      expect(item.rarity).toBe('common');
    });

    test('should validate required fields', async () => {
      const item = new UserItem({});
      
      let error;
      try {
        await item.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.errors.userId).toBeDefined();
      expect(error.errors.name).toBeDefined();
      expect(error.errors.category).toBeDefined();
      expect(error.errors.type).toBeDefined();
    });

    test('should calculate age in days', async () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      const item = new UserItem({
        userId: testUser._id,
        name: 'Test Item',
        category: 'collectible',
        type: 'physical',
        location: {
          source: 'adventure',
          acquiredAt: yesterday
        }
      });

      await item.save();
      expect(item.ageInDays).toBe(1);
    });
  });

  describe('UserItem Service', () => {
    test('should create user item', async () => {
      const itemData = {
        name: 'Concert Ticket',
        category: 'ticket',
        type: 'physical',
        source: 'event',
        tags: ['music', 'concert'],
        notes: 'Amazing show!'
      };

      const item = await userItemService.createUserItem(testUser._id, itemData);

      expect(item.name).toBe('Concert Ticket');
      expect(item.userId.toString()).toBe(testUser._id.toString());
      expect(item.metadata.tags).toContain('music');
      expect(item.metadata.notes).toBe('Amazing show!');
    });

    test('should get user items with filters', async () => {
      // Create test items
      await userItemService.createUserItem(testUser._id, {
        name: 'Badge 1',
        category: 'badge',
        type: 'achievement'
      });

      await userItemService.createUserItem(testUser._id, {
        name: 'Photo 1',
        category: 'photo',
        type: 'digital'
      });

      // Get all items
      const allItems = await userItemService.getUserItems(testUser._id);
      expect(allItems).toHaveLength(2);

      // Get only badges
      const badges = await userItemService.getUserItems(testUser._id, { category: 'badge' });
      expect(badges).toHaveLength(1);
      expect(badges[0].name).toBe('Badge 1');
    });

    test('should update user item', async () => {
      const item = await userItemService.createUserItem(testUser._id, {
        name: 'Original Name',
        category: 'collectible',
        type: 'physical'
      });

      const updatedItem = await userItemService.updateUserItem(testUser._id, item._id, {
        name: 'Updated Name',
        metadata: { isFavorite: true }
      });

      expect(updatedItem.name).toBe('Updated Name');
      expect(updatedItem.metadata.isFavorite).toBe(true);
    });

    test('should toggle favorite status', async () => {
      const item = await userItemService.createUserItem(testUser._id, {
        name: 'Test Item',
        category: 'collectible',
        type: 'physical'
      });

      expect(item.metadata.isFavorite).toBe(false);

      const toggledItem = await userItemService.toggleFavorite(testUser._id, item._id);
      expect(toggledItem.metadata.isFavorite).toBe(true);

      const toggledAgain = await userItemService.toggleFavorite(testUser._id, item._id);
      expect(toggledAgain.metadata.isFavorite).toBe(false);
    });

    test('should add memory to item', async () => {
      const item = await userItemService.createUserItem(testUser._id, {
        name: 'Special Item',
        category: 'souvenir',
        type: 'physical'
      });

      const memoryData = {
        title: 'Great Adventure',
        description: 'Had an amazing time!',
        emotion: 'happy'
      };

      const updatedItem = await userItemService.addItemMemory(testUser._id, item._id, memoryData);
      expect(updatedItem.metadata.memories).toHaveLength(1);
      expect(updatedItem.metadata.memories[0].title).toBe('Great Adventure');
      expect(updatedItem.metadata.memories[0].emotion).toBe('happy');
    });

    test('should get user item statistics', async () => {
      // Create various items
      await userItemService.createUserItem(testUser._id, {
        name: 'Badge 1',
        category: 'badge',
        type: 'achievement',
        rarity: 'rare',
        value: { points: 100 }
      });

      await userItemService.createUserItem(testUser._id, {
        name: 'Photo 1',
        category: 'photo',
        type: 'digital',
        rarity: 'common',
        value: { points: 10 },
        isFavorite: true
      });

      const stats = await userItemService.getUserItemStats(testUser._id);
      
      expect(stats.totalItems).toBe(2);
      expect(stats.totalValue).toBe(110);
      expect(stats.favoriteCount).toBe(1);
      expect(stats.categoryStats).toHaveLength(2);
      expect(stats.rarityStats).toHaveLength(2);
    });

    test('should search user items', async () => {
      await userItemService.createUserItem(testUser._id, {
        name: 'Concert Ticket',
        description: 'Rock concert at Madison Square Garden',
        category: 'ticket',
        type: 'physical',
        tags: ['music', 'rock']
      });

      await userItemService.createUserItem(testUser._id, {
        name: 'Photo Album',
        description: 'Photos from the beach vacation',
        category: 'photo',
        type: 'digital',
        tags: ['vacation', 'beach']
      });

      // Search by name
      const concertResults = await userItemService.searchUserItems(testUser._id, 'concert');
      expect(concertResults).toHaveLength(1);
      expect(concertResults[0].name).toBe('Concert Ticket');

      // Search by description
      const beachResults = await userItemService.searchUserItems(testUser._id, 'beach');
      expect(beachResults).toHaveLength(1);
      expect(beachResults[0].name).toBe('Photo Album');

      // Search by tag
      const musicResults = await userItemService.searchUserItems(testUser._id, 'music');
      expect(musicResults).toHaveLength(1);
    });
  });

  describe('UserItem API Routes', () => {
    test('GET /api/user-items should return user items', async () => {
      // Create test item
      await userItemService.createUserItem(testUser._id, {
        name: 'API Test Item',
        category: 'collectible',
        type: 'physical'
      });

      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(1);
      expect(response.body.data[0].name).toBe('API Test Item');
    });

    test('POST /api/user-items should create new item', async () => {
      const itemData = {
        name: 'New API Item',
        category: 'badge',
        type: 'achievement',
        rarity: 'epic',
        value: { points: 500 }
      };

      const response = await request(app)
        .post('/api/user-items')
        .set('Authorization', `Bearer ${authToken}`)
        .send(itemData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('New API Item');
      expect(response.body.data.rarity).toBe('epic');
      expect(response.body.data.value.points).toBe(500);
    });

    test('PUT /api/user-items/:itemId should update item', async () => {
      const item = await userItemService.createUserItem(testUser._id, {
        name: 'Original Item',
        category: 'collectible',
        type: 'physical'
      });

      const updateData = {
        name: 'Updated Item',
        metadata: { isFavorite: true }
      };

      const response = await request(app)
        .put(`/api/user-items/${item._id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updateData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Updated Item');
      expect(response.body.data.metadata.isFavorite).toBe(true);
    });

    test('PATCH /api/user-items/:itemId/favorite should toggle favorite', async () => {
      const item = await userItemService.createUserItem(testUser._id, {
        name: 'Favorite Test Item',
        category: 'collectible',
        type: 'physical'
      });

      const response = await request(app)
        .patch(`/api/user-items/${item._id}/favorite`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.isFavorite).toBe(true);
    });

    test('GET /api/user-items/stats should return statistics', async () => {
      // Create test items
      await userItemService.createUserItem(testUser._id, {
        name: 'Stats Test 1',
        category: 'badge',
        type: 'achievement',
        value: { points: 100 }
      });

      await userItemService.createUserItem(testUser._id, {
        name: 'Stats Test 2',
        category: 'photo',
        type: 'digital',
        value: { points: 50 }
      });

      const response = await request(app)
        .get('/api/user-items/stats')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.totalItems).toBe(2);
      expect(response.body.data.totalValue).toBe(150);
    });

    test('DELETE /api/user-items/:itemId should delete item', async () => {
      const item = await userItemService.createUserItem(testUser._id, {
        name: 'Delete Test Item',
        category: 'collectible',
        type: 'physical'
      });

      const response = await request(app)
        .delete(`/api/user-items/${item._id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);

      // Verify item is soft deleted
      const deletedItem = await UserItem.findById(item._id);
      expect(deletedItem.status).toBe('deleted');
    });

    test('should validate request data', async () => {
      const invalidData = {
        name: '', // Empty name should fail
        category: 'invalid_category', // Invalid category
        type: 'invalid_type' // Invalid type
      };

      const response = await request(app)
        .post('/api/user-items')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toBe('Validation error');
      expect(response.body.errors).toBeDefined();
    });

    test('should require authentication', async () => {
      const response = await request(app)
        .get('/api/user-items')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });
});
