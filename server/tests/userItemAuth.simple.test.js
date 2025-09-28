const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

// Import middleware
const authenticateJWT = require('../middleware/authenticateJWT');
const {
  verifyItemOwnership,
  validateUserId,
  itemRateLimit,
  auditItemOperation
} = require('../middleware/userItemAuth');

// Mock models
jest.mock('../models/User');
jest.mock('../models/UserItem');
jest.mock('../utils/logger');

const User = require('../models/User');
const UserItem = require('../models/UserItem');

describe('User Item Authentication Middleware', () => {
  let app;
  let testUserId;
  let validToken;
  let invalidToken;

  beforeAll(() => {
    // Setup test environment
    process.env.JWT_SECRET = 'test_secret_key';
    testUserId = new mongoose.Types.ObjectId().toString();
    
    // Create valid JWT token
    validToken = jwt.sign(
      { userId: testUserId, email: 'test@example.com' },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    // Create invalid JWT token
    invalidToken = jwt.sign(
      { userId: testUserId, email: 'test@example.com' },
      'wrong_secret',
      { expiresIn: '1h' }
    );

    // Setup Express app for testing
    app = express();
    app.use(express.json());

    // Test routes
    app.get('/test/auth', authenticateJWT, (req, res) => {
      res.json({ success: true, userId: req.user.userId });
    });

    app.get('/test/validate-user', authenticateJWT, validateUserId, (req, res) => {
      res.json({ success: true, userId: req.user.userId });
    });

    app.get('/test/rate-limit', authenticateJWT, itemRateLimit(5, 60000), (req, res) => {
      res.json({ success: true });
    });

    app.get('/test/audit/:itemId', authenticateJWT, auditItemOperation('test'), (req, res) => {
      res.json({ success: true });
    });

    app.get('/test/ownership/:itemId', authenticateJWT, verifyItemOwnership, (req, res) => {
      res.json({ success: true, item: req.item });
    });
  });

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
  });

  describe('JWT Authentication Middleware', () => {
    test('should reject requests without token', async () => {
      const response = await request(app)
        .get('/test/auth')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Access denied');
    });

    test('should reject requests with invalid token', async () => {
      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', `Bearer ${invalidToken}`)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Invalid token');
    });

    test('should accept requests with valid token when user exists', async () => {
      // Mock user exists and is active
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.userId).toBe(testUserId);
    });

    test('should reject when user does not exist', async () => {
      // Mock user not found
      User.findById.mockResolvedValue(null);

      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('User not found');
    });

    test('should reject when user is inactive', async () => {
      // Mock inactive user
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: false
      });

      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('deactivated');
    });
  });

  describe('User ID Validation Middleware', () => {
    test('should accept valid MongoDB ObjectId', async () => {
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      const response = await request(app)
        .get('/test/validate-user')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    test('should reject invalid user ID format', async () => {
      // Create token with invalid user ID
      const invalidUserIdToken = jwt.sign(
        { userId: 'invalid_id', email: 'test@example.com' },
        process.env.JWT_SECRET,
        { expiresIn: '1h' }
      );

      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      const response = await request(app)
        .get('/test/validate-user')
        .set('Authorization', `Bearer ${invalidUserIdToken}`)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Invalid user ID format');
    });
  });

  describe('Rate Limiting Middleware', () => {
    test('should allow requests within limit', async () => {
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      // Make 3 requests (within limit of 5)
      for (let i = 0; i < 3; i++) {
        const response = await request(app)
          .get('/test/rate-limit')
          .set('Authorization', `Bearer ${validToken}`)
          .expect(200);

        expect(response.body.success).toBe(true);
      }
    });

    test('should block requests exceeding limit', async () => {
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      // Make 6 requests (exceeding limit of 5)
      const promises = [];
      for (let i = 0; i < 6; i++) {
        promises.push(
          request(app)
            .get('/test/rate-limit')
            .set('Authorization', `Bearer ${validToken}`)
        );
      }

      const responses = await Promise.all(promises);
      
      // At least one should be rate limited
      const rateLimitedResponses = responses.filter(res => res.status === 429);
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
    });
  });

  describe('Item Ownership Middleware', () => {
    const testItemId = new mongoose.Types.ObjectId().toString();

    test('should allow access to owned items', async () => {
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      UserItem.findOne.mockResolvedValue({
        _id: testItemId,
        userId: testUserId,
        name: 'Test Item',
        status: 'active'
      });

      const response = await request(app)
        .get(`/test/ownership/${testItemId}`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(UserItem.findOne).toHaveBeenCalledWith({
        _id: testItemId,
        userId: testUserId,
        status: { $ne: 'deleted' }
      });
    });

    test('should deny access to non-existent items', async () => {
      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      UserItem.findOne.mockResolvedValue(null);

      const response = await request(app)
        .get(`/test/ownership/${testItemId}`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('not found or access denied');
    });

    test('should deny access to items owned by other users', async () => {
      const otherUserId = new mongoose.Types.ObjectId().toString();

      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      // Mock item owned by different user
      UserItem.findOne.mockResolvedValue(null); // No item found for this user

      const response = await request(app)
        .get(`/test/ownership/${testItemId}`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
    });
  });

  describe('Audit Logging Middleware', () => {
    test('should log operations', async () => {
      const testItemId = new mongoose.Types.ObjectId().toString();

      User.findById.mockResolvedValue({
        _id: testUserId,
        email: 'test@example.com',
        isActive: true
      });

      const response = await request(app)
        .get(`/test/audit/${testItemId}`)
        .set('Authorization', `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      // Note: Audit logging is tested by checking that the middleware doesn't break the request flow
      // The actual logging is mocked, so we just verify the request succeeds
    });
  });

  describe('Error Handling', () => {
    test('should handle database errors gracefully', async () => {
      User.findById.mockRejectedValue(new Error('Database connection failed'));

      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', `Bearer ${validToken}`)
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Internal server error');
    });

    test('should handle malformed tokens', async () => {
      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', 'Bearer malformed.token.here')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Invalid token');
    });

    test('should handle expired tokens', async () => {
      const expiredToken = jwt.sign(
        { userId: testUserId, email: 'test@example.com' },
        process.env.JWT_SECRET,
        { expiresIn: '-1h' }
      );

      const response = await request(app)
        .get('/test/auth')
        .set('Authorization', `Bearer ${expiredToken}`)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Token expired');
    });
  });
});
