const { logger } = require('../utils/logger');
const { client: redis, connectRedis } = require('../config/redisClient');

class UserStatusService {
  constructor() {
    this.onlineUsers = new Map(); // socketId -> { userId, lastSeen, status }
    this.userSockets = new Map(); // userId -> Set of socketIds
  }

  // Add user connection
  async addConnection(socketId, userId, userName) {
    try {
      // Store in memory
      this.onlineUsers.set(socketId, {
        userId,
        userName,
        lastSeen: new Date(),
        status: 'online'
      });

      // Add to user's socket set
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId).add(socketId);

      // Store in Redis for persistence across server restarts
      await connectRedis();
      await redis.setex(`user:${userId}:status`, 300, JSON.stringify({
        status: 'online',
        lastSeen: new Date().toISOString(),
        userName
      }));

      logger.info('User Status - Connection Added', { userId, userName, socketId });
      
      return this.getUserStatus(userId);
    } catch (error) {
      logger.error('User Status - Add Connection Error', { error: error.message, userId, socketId });
      throw error;
    }
  }

  // Remove user connection
  async removeConnection(socketId) {
    try {
      const connection = this.onlineUsers.get(socketId);
      if (!connection) return null;

      const { userId, userName } = connection;
      
      // Remove from memory
      this.onlineUsers.delete(socketId);
      
      // Remove from user's socket set
      if (this.userSockets.has(userId)) {
        this.userSockets.get(userId).delete(socketId);
        
        // If no more sockets for this user, mark as offline
        if (this.userSockets.get(userId).size === 0) {
          this.userSockets.delete(userId);
          
          // Update Redis status to offline
          await connectRedis();
          await redis.setex(`user:${userId}:status`, 300, JSON.stringify({
            status: 'offline',
            lastSeen: new Date().toISOString(),
            userName
          }));
        }
      }

      logger.info('User Status - Connection Removed', { userId, userName, socketId });
      
      return { userId, userName, status: this.isUserOnline(userId) ? 'online' : 'offline' };
    } catch (error) {
      logger.error('User Status - Remove Connection Error', { error: error.message, socketId });
      throw error;
    }
  }

  // Update user status (online, away, busy, offline)
  async updateUserStatus(userId, status) {
    try {
      const validStatuses = ['online', 'away', 'busy', 'offline'];
      if (!validStatuses.includes(status)) {
        throw new Error(`Invalid status: ${status}`);
      }

      // Update all user's connections
      const userSockets = this.userSockets.get(userId);
      if (userSockets) {
        for (const socketId of userSockets) {
          const connection = this.onlineUsers.get(socketId);
          if (connection) {
            connection.status = status;
            connection.lastSeen = new Date();
          }
        }
      }

      // Update Redis
      await connectRedis();
      const existingStatus = await this.getUserStatusFromRedis(userId);
      await redis.setex(`user:${userId}:status`, 300, JSON.stringify({
        status,
        lastSeen: new Date().toISOString(),
        userName: existingStatus?.userName || 'Unknown User'
      }));

      logger.info('User Status - Status Updated', { userId, status });
      
      return this.getUserStatus(userId);
    } catch (error) {
      logger.error('User Status - Update Status Error', { error: error.message, userId, status });
      throw error;
    }
  }

  // Check if user is online
  isUserOnline(userId) {
    return this.userSockets.has(userId) && this.userSockets.get(userId).size > 0;
  }

  // Get user status
  async getUserStatus(userId) {
    try {
      // Check memory first
      if (this.isUserOnline(userId)) {
        const userSockets = this.userSockets.get(userId);
        const firstSocketId = userSockets.values().next().value;
        const connection = this.onlineUsers.get(firstSocketId);
        
        return {
          userId,
          status: connection?.status || 'online',
          lastSeen: connection?.lastSeen || new Date(),
          isOnline: true,
          userName: connection?.userName
        };
      }

      // Check Redis for offline status
      const redisStatus = await this.getUserStatusFromRedis(userId);
      if (redisStatus) {
        return {
          userId,
          status: redisStatus.status,
          lastSeen: new Date(redisStatus.lastSeen),
          isOnline: false,
          userName: redisStatus.userName
        };
      }

      // Default offline status
      return {
        userId,
        status: 'offline',
        lastSeen: new Date(),
        isOnline: false,
        userName: 'Unknown User'
      };
    } catch (error) {
      logger.error('User Status - Get Status Error', { error: error.message, userId });
      return {
        userId,
        status: 'offline',
        lastSeen: new Date(),
        isOnline: false,
        userName: 'Unknown User'
      };
    }
  }

  // Get multiple user statuses
  async getMultipleUserStatuses(userIds) {
    try {
      const statuses = await Promise.all(
        userIds.map(userId => this.getUserStatus(userId))
      );
      
      return statuses.reduce((acc, status) => {
        acc[status.userId] = status;
        return acc;
      }, {});
    } catch (error) {
      logger.error('User Status - Get Multiple Statuses Error', { error: error.message, userIds });
      return {};
    }
  }

  // Get all online users
  getOnlineUsers() {
    const onlineUsers = [];
    for (const [userId, socketIds] of this.userSockets) {
      if (socketIds.size > 0) {
        const firstSocketId = socketIds.values().next().value;
        const connection = this.onlineUsers.get(firstSocketId);
        if (connection) {
          onlineUsers.push({
            userId,
            userName: connection.userName,
            status: connection.status,
            lastSeen: connection.lastSeen
          });
        }
      }
    }
    return onlineUsers;
  }

  // Get user sockets
  getUserSockets(userId) {
    return Array.from(this.userSockets.get(userId) || []);
  }

  // Update last seen timestamp
  updateLastSeen(socketId) {
    const connection = this.onlineUsers.get(socketId);
    if (connection) {
      connection.lastSeen = new Date();
    }
  }

  // Helper to get status from Redis
  async getUserStatusFromRedis(userId) {
    try {
      await connectRedis();
      const statusData = await redis.get(`user:${userId}:status`);
      return statusData ? JSON.parse(statusData) : null;
    } catch (error) {
      logger.error('User Status - Redis Get Error', { error: error.message, userId });
      return null;
    }
  }

  // Cleanup expired connections
  async cleanup() {
    try {
      const now = new Date();
      const expiredConnections = [];

      // Find expired connections (older than 5 minutes)
      for (const [socketId, connection] of this.onlineUsers) {
        const timeDiff = now - connection.lastSeen;
        if (timeDiff > 300000) { // 5 minutes
          expiredConnections.push(socketId);
        }
      }

      // Remove expired connections
      for (const socketId of expiredConnections) {
        await this.removeConnection(socketId);
      }

      if (expiredConnections.length > 0) {
        logger.info('User Status - Cleanup', { expiredConnections: expiredConnections.length });
      }
    } catch (error) {
      logger.error('User Status - Cleanup Error', { error: error.message });
    }
  }
}

// Create singleton instance
const userStatusService = new UserStatusService();

// Run cleanup every 5 minutes
setInterval(() => {
  userStatusService.cleanup();
}, 300000);

module.exports = userStatusService;
