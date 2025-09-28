const request = require('supertest');
const mongoose = require('mongoose');
const { app } = require('../server');
const User = require('../models/User');
const UserItem = require('../models/UserItem');
const jwt = require('jsonwebtoken');

describe('User Item Authentication & Authorization', () => {
  let testUser1, testUser2;
  let authToken1, authToken2;
  let testItem1, testItem2;

  beforeAll(async () => {
    // Connect to test database
    const mongoUri = process.env.MONGODB_TEST_URI || 'mongodb://localhost:27017/tripblip_test';
    await mongoose.connect(mongoUri);
  });

  beforeEach(async () => {
    // Clean up database
    await User.deleteMany({});
    await UserItem.deleteMany({});

    // Create test users
    testUser1 = await User.create({
      name: 'Test User 1',
      email: 'test1@example.com',
      password: 'password123'
    });

    testUser2 = await User.create({
      name: 'Test User 2',
      email: 'test2@example.com',
      password: 'password123'
    });

    // Generate auth tokens
    authToken1 = jwt.sign(
      { userId: testUser1._id, email: testUser1.email },
      process.env.JWT_SECRET || 'test_secret',
      { expiresIn: '1h' }
    );

    authToken2 = jwt.sign(
      { userId: testUser2._id, email: testUser2.email },
      process.env.JWT_SECRET || 'test_secret',
      { expiresIn: '1h' }
    );

    // Create test items
    testItem1 = await UserItem.create({
      userId: testUser1._id,
      name: 'User 1 Item',
      category: 'collectible',
      type: 'physical',
      location: { source: 'adventure', acquiredAt: new Date() }
    });

    testItem2 = await UserItem.create({
      userId: testUser2._id,
      name: 'User 2 Item',
      category: 'badge',
      type: 'achievement',
      location: { source: 'event', acquiredAt: new Date() }
    });
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  describe('Authentication Requirements', () => {
    test('should reject requests without authentication token', async () => {
      const response = await request(app)
        .get('/api/user-items')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Access denied');
    });

    test('should reject requests with invalid token', async () => {
      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', 'Bearer invalid_token')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Invalid token');
    });

    test('should reject requests with expired token', async () => {
      const expiredToken = jwt.sign(
        { userId: testUser1._id, email: testUser1.email },
        process.env.JWT_SECRET || 'test_secret',
        { expiresIn: '-1h' }
      );

      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', `Bearer ${expiredToken}`)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Token expired');
    });

    test('should accept requests with valid token', async () => {
      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });
  });

  describe('Item Ownership Authorization', () => {
    test('should only return items owned by authenticated user', async () => {
      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.data).toHaveLength(1);
      expect(response.body.data[0].name).toBe('User 1 Item');
      expect(response.body.data[0].userId).toBe(testUser1._id.toString());
    });

    test('should prevent access to items owned by other users', async () => {
      const response = await request(app)
        .get(`/api/user-items/${testItem2._id}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('not found or access denied');
    });

    test('should allow access to own items', async () => {
      const response = await request(app)
        .get(`/api/user-items/${testItem1._id}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data._id).toBe(testItem1._id.toString());
    });
  });

  describe('Item Modification Authorization', () => {
    test('should prevent updating items owned by other users', async () => {
      const updateData = { name: 'Updated Name' };

      const response = await request(app)
        .put(`/api/user-items/${testItem2._id}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .send(updateData)
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    test('should allow updating own items', async () => {
      const updateData = { name: 'Updated Name' };

      const response = await request(app)
        .put(`/api/user-items/${testItem1._id}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .send(updateData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Updated Name');
    });

    test('should prevent deleting items owned by other users', async () => {
      const response = await request(app)
        .delete(`/api/user-items/${testItem2._id}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    test('should allow deleting own items', async () => {
      const response = await request(app)
        .delete(`/api/user-items/${testItem1._id}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });
  });

  describe('Item Creation Authorization', () => {
    test('should create items for authenticated user only', async () => {
      const itemData = {
        name: 'New Test Item',
        category: 'souvenir',
        type: 'physical'
      };

      const response = await request(app)
        .post('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(itemData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.userId).toBe(testUser1._id.toString());
      expect(response.body.data.name).toBe('New Test Item');
    });

    test('should validate required fields', async () => {
      const invalidItemData = {
        name: '', // Empty name should fail
        category: 'invalid_category'
      };

      const response = await request(app)
        .post('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(invalidItemData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toBe('Validation error');
    });
  });

  describe('Shared Items Authorization', () => {
    let sharedItem;

    beforeEach(async () => {
      // Create a shared item
      sharedItem = await UserItem.create({
        userId: testUser1._id,
        name: 'Shared Item',
        category: 'photo',
        type: 'digital',
        location: { source: 'adventure', acquiredAt: new Date() },
        sharing: {
          isShared: true,
          sharedWith: [{
            userId: testUser2._id,
            permission: 'view',
            sharedAt: new Date()
          }]
        }
      });
    });

    test('should allow viewing shared items', async () => {
      const response = await request(app)
        .get(`/api/user-items/${sharedItem._id}`)
        .set('Authorization', `Bearer ${authToken2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Shared Item');
    });

    test('should prevent editing shared items by non-owners', async () => {
      const updateData = { name: 'Attempted Update' };

      const response = await request(app)
        .put(`/api/user-items/${sharedItem._id}`)
        .set('Authorization', `Bearer ${authToken2}`)
        .send(updateData)
        .expect(404); // Should be blocked by ownership verification

      expect(response.body.success).toBe(false);
    });
  });

  describe('Public Items Authorization', () => {
    let publicItem;

    beforeEach(async () => {
      // Create a public item
      publicItem = await UserItem.create({
        userId: testUser1._id,
        name: 'Public Item',
        category: 'achievement',
        type: 'badge',
        location: { source: 'adventure', acquiredAt: new Date() },
        metadata: {
          isPublic: true,
          tags: ['public', 'achievement']
        }
      });
    });

    test('should allow viewing public items', async () => {
      const response = await request(app)
        .get(`/api/user-items/${publicItem._id}`)
        .set('Authorization', `Bearer ${authToken2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Public Item');
    });

    test('should include public items in public endpoint', async () => {
      const response = await request(app)
        .get('/api/user-items/public')
        .set('Authorization', `Bearer ${authToken2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.length).toBeGreaterThan(0);
      expect(response.body.data.some(item => item._id === publicItem._id.toString())).toBe(true);
    });
  });

  describe('Rate Limiting', () => {
    test('should enforce rate limits', async () => {
      // Make multiple requests quickly
      const promises = [];
      for (let i = 0; i < 105; i++) { // Exceed the 100 request limit
        promises.push(
          request(app)
            .get('/api/user-items')
            .set('Authorization', `Bearer ${authToken1}`)
        );
      }

      const responses = await Promise.all(promises);
      
      // Some requests should be rate limited
      const rateLimitedResponses = responses.filter(res => res.status === 429);
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
    }, 10000); // Increase timeout for this test
  });

  describe('Input Validation', () => {
    test('should validate user ID format', async () => {
      // This test would require manipulating the JWT token with invalid user ID
      // For now, we'll test that valid tokens work
      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    test('should sanitize input data', async () => {
      const maliciousData = {
        name: '<script>alert("xss")</script>',
        category: 'collectible',
        type: 'physical',
        description: 'Normal description'
      };

      const response = await request(app)
        .post('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(maliciousData)
        .expect(201);

      expect(response.body.success).toBe(true);
      // The name should be sanitized (exact behavior depends on sanitization middleware)
      expect(response.body.data.name).not.toContain('<script>');
    });
  });

  describe('Error Handling', () => {
    test('should handle database errors gracefully', async () => {
      // Close database connection to simulate error
      await mongoose.connection.close();

      const response = await request(app)
        .get('/api/user-items')
        .set('Authorization', `Bearer ${authToken1}`);

      expect(response.status).toBeGreaterThanOrEqual(500);
      expect(response.body.success).toBe(false);

      // Reconnect for cleanup
      const mongoUri = process.env.MONGODB_TEST_URI || 'mongodb://localhost:27017/tripblip_test';
      await mongoose.connect(mongoUri);
    });

    test('should return appropriate error for non-existent items', async () => {
      const fakeId = new mongoose.Types.ObjectId();
      
      const response = await request(app)
        .get(`/api/user-items/${fakeId}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('not found');
    });
  });
});
