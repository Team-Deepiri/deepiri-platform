const redis = require('redis');
const logger = require('../utils/logger');

class CacheService {
  constructor() {
    this.client = null;
    this.isConnected = false;
  }

  async initialize() {
    try {
      // Build Redis URL from environment variables
      const redisHost = process.env.REDIS_HOST || 'localhost';
      const redisPort = process.env.REDIS_PORT || '6379';
      const redisPassword = process.env.REDIS_PASSWORD;
      
      let redisUrl = `redis://${redisHost}:${redisPort}`;
      if (redisPassword) {
        redisUrl = `redis://:${redisPassword}@${redisHost}:${redisPort}`;
      }
      
      // Use REDIS_URL if provided, otherwise construct from components
      const finalRedisUrl = process.env.REDIS_URL || redisUrl;
      
      this.client = redis.createClient({
        url: finalRedisUrl,
        retry_strategy: (options) => {
          if (options.error && options.error.code === 'ECONNREFUSED') {
            logger.error('Redis server connection refused');
            return new Error('Redis server connection refused');
          }
          if (options.total_retry_time > 1000 * 60 * 60) {
            logger.error('Redis retry time exhausted');
            return new Error('Retry time exhausted');
          }
          if (options.attempt > 10) {
            logger.error('Redis max retry attempts reached');
            return undefined;
          }
          return Math.min(options.attempt * 100, 3000);
        }
      });

      this.client.on('error', (err) => {
        logger.error('Redis Client Error:', err);
        this.isConnected = false;
      });

      this.client.on('connect', () => {
        logger.info('Redis client connected');
        this.isConnected = true;
      });

      this.client.on('ready', () => {
        logger.info('Redis client ready');
        this.isConnected = true;
      });

      this.client.on('end', () => {
        logger.info('Redis client disconnected');
        this.isConnected = false;
      });

      await this.client.connect();
    } catch (error) {
      logger.error('Failed to initialize Redis:', error);
      this.isConnected = false;
    }
  }

  getConnectionStatus() {
    return this.isConnected;
  }

  async get(key) {
    try {
      if (!this.isConnected) {
        logger.warn('Redis not connected, skipping cache get');
        return null;
      }
      
      const value = await this.client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      logger.error('Cache get error:', error);
      return null;
    }
  }

  async set(key, value, ttl = null) {
    try {
      if (!this.isConnected) {
        logger.warn('Redis not connected, skipping cache set');
        return false;
      }

      const serializedValue = JSON.stringify(value);
      
      if (ttl) {
        await this.client.setEx(key, ttl, serializedValue);
      } else {
        await this.client.set(key, serializedValue);
      }
      
      return true;
    } catch (error) {
      logger.error('Cache set error:', error);
      return false;
    }
  }

  async del(key) {
    try {
      if (!this.isConnected) {
        logger.warn('Redis not connected, skipping cache delete');
        return false;
      }

      await this.client.del(key);
      return true;
    } catch (error) {
      logger.error('Cache delete error:', error);
      return false;
    }
  }

  async exists(key) {
    try {
      if (!this.isConnected) {
        return false;
      }

      const result = await this.client.exists(key);
      return result === 1;
    } catch (error) {
      logger.error('Cache exists error:', error);
      return false;
    }
  }

  async expire(key, ttl) {
    try {
      if (!this.isConnected) {
        return false;
      }

      await this.client.expire(key, ttl);
      return true;
    } catch (error) {
      logger.error('Cache expire error:', error);
      return false;
    }
  }

  // Adventure-specific cache methods
  async getAdventure(userId, location, interests) {
    const key = `adventure:${userId}:${location.lat}:${location.lng}:${interests.join(',')}`;
    return await this.get(key);
  }

  async setAdventure(userId, location, interests, adventure, ttl = null) {
    const key = `adventure:${userId}:${location.lat}:${location.lng}:${interests.join(',')}`;
    const cacheTtl = ttl || parseInt(process.env.CACHE_TTL_ADVENTURES) || 3600;
    return await this.set(key, adventure, cacheTtl);
  }

  // Event-specific cache methods
  async getEvents(location, radius, category = null) {
    const key = `events:${location.lat}:${location.lng}:${radius}${category ? `:${category}` : ''}`;
    return await this.get(key);
  }

  async setEvents(location, radius, events, category = null, ttl = null) {
    const key = `events:${location.lat}:${location.lng}:${radius}${category ? `:${category}` : ''}`;
    const cacheTtl = ttl || parseInt(process.env.CACHE_TTL_EVENTS) || 1800;
    return await this.set(key, events, cacheTtl);
  }

  // Weather-specific cache methods
  async getWeather(location) {
    const key = `weather:${location.lat}:${location.lng}`;
    return await this.get(key);
  }

  async setWeather(location, weather, ttl = null) {
    const key = `weather:${location.lat}:${location.lng}`;
    const cacheTtl = ttl || parseInt(process.env.CACHE_TTL_WEATHER) || 900;
    return await this.set(key, weather, cacheTtl);
  }

  // Maps-specific cache methods
  async getRoute(from, to, mode = 'walking') {
    const key = `route:${from.lat}:${from.lng}:${to.lat}:${to.lng}:${mode}`;
    return await this.get(key);
  }

  async setRoute(from, to, route, mode = 'walking', ttl = null) {
    const key = `route:${from.lat}:${from.lng}:${to.lat}:${to.lng}:${mode}`;
    const cacheTtl = ttl || parseInt(process.env.CACHE_TTL_MAPS) || 3600;
    return await this.set(key, route, cacheTtl);
  }

  // User-specific cache methods
  async getUserPreferences(userId) {
    const key = `user:${userId}:preferences`;
    return await this.get(key);
  }

  async setUserPreferences(userId, preferences, ttl = null) {
    const key = `user:${userId}:preferences`;
    const cacheTtl = ttl || 3600; // 1 hour
    return await this.set(key, preferences, cacheTtl);
  }

  // Clear user cache
  async clearUserCache(userId) {
    const pattern = `user:${userId}:*`;
    try {
      if (!this.isConnected) {
        return false;
      }

      const keys = await this.client.keys(pattern);
      if (keys.length > 0) {
        await this.client.del(keys);
      }
      return true;
    } catch (error) {
      logger.error('Clear user cache error:', error);
      return false;
    }
  }

  // User Items cache methods
  async getUserItems(userId, options = {}) {
    const key = `user_items:${userId}:${JSON.stringify(options)}`;
    return await this.get(key);
  }

  async setUserItems(userId, items, options = {}, ttl = null) {
    const key = `user_items:${userId}:${JSON.stringify(options)}`;
    const cacheTtl = ttl || 1800; // 30 minutes
    return await this.set(key, items, cacheTtl);
  }

  async getUserItemStats(userId) {
    const key = `user_item_stats:${userId}`;
    return await this.get(key);
  }

  async setUserItemStats(userId, stats, ttl = null) {
    const key = `user_item_stats:${userId}`;
    const cacheTtl = ttl || 3600; // 1 hour
    return await this.set(key, stats, cacheTtl);
  }

  // Clear user items cache
  async clearUserItemsCache(userId) {
    const patterns = [`user_items:${userId}:*`, `user_item_stats:${userId}`];
    try {
      if (!this.isConnected) {
        return false;
      }

      for (const pattern of patterns) {
        const keys = await this.client.keys(pattern);
        if (keys.length > 0) {
          await this.client.del(keys);
        }
      }
      return true;
    } catch (error) {
      logger.error('Clear user items cache error:', error);
      return false;
    }
  }

  // Clear all cache
  async clearAll() {
    try {
      if (!this.isConnected) {
        return false;
      }

      await this.client.flushAll();
      return true;
    } catch (error) {
      logger.error('Clear all cache error:', error);
      return false;
    }
  }

  // Get cache statistics
  async getStats() {
    try {
      if (!this.isConnected) {
        return null;
      }

      const info = await this.client.info('memory');
      const keyspace = await this.client.info('keyspace');
      
      return {
        memory: info,
        keyspace: keyspace,
        connected: this.isConnected
      };
    } catch (error) {
      logger.error('Cache stats error:', error);
      return null;
    }
  }

  async disconnect() {
    try {
      if (this.client) {
        await this.client.quit();
        this.isConnected = false;
        logger.info('Redis client disconnected');
      }
    } catch (error) {
      logger.error('Redis disconnect error:', error);
    }
  }
}

module.exports = new CacheService();
