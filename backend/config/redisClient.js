const Redis = require('ioredis');
const config = require('./environment');

// Create Redis client with configuration
const redisClient = new Redis(config.redisUrl, {
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
  lazyConnect: true
});

// Connection function for compatibility
const connectRedis = async () => {
  if (redisClient.status !== 'ready') {
    await redisClient.connect();
  }
};

// Export both client and connect function
module.exports = {
  client: redisClient,
  connectRedis
};
