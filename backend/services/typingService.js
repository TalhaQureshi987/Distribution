const { logger } = require('../utils/logger');

class TypingService {
  constructor() {
    this.typingUsers = new Map(); // roomId -> Map(userId -> { timer, userName, startTime })
  }

  // Start typing indicator
  startTyping(roomId, userId, userName, socketServer) {
    try {
      if (!this.typingUsers.has(roomId)) {
        this.typingUsers.set(roomId, new Map());
      }

      const roomTyping = this.typingUsers.get(roomId);
      
      // Clear existing timer if user was already typing
      if (roomTyping.has(userId)) {
        clearTimeout(roomTyping.get(userId).timer);
      }

      // Set new typing indicator with auto-clear timer
      const timer = setTimeout(() => {
        this.stopTyping(roomId, userId, socketServer);
      }, 10000); // Auto-clear after 10 seconds

      roomTyping.set(userId, {
        timer,
        userName,
        startTime: new Date()
      });

      // Emit typing event to other users in room
      socketServer.emitToRoomExcept(roomId, userId, 'userTyping', {
        roomId,
        userId,
        userName,
        isTyping: true,
        timestamp: new Date().toISOString()
      });

      logger.debug('Typing Service - Started', { roomId, userId, userName });
      
      return true;
    } catch (error) {
      logger.error('Typing Service - Start Error', { error: error.message, roomId, userId });
      return false;
    }
  }

  // Stop typing indicator
  stopTyping(roomId, userId, socketServer) {
    try {
      const roomTyping = this.typingUsers.get(roomId);
      if (!roomTyping || !roomTyping.has(userId)) {
        return false;
      }

      const typingData = roomTyping.get(userId);
      
      // Clear timer
      clearTimeout(typingData.timer);
      
      // Remove from typing users
      roomTyping.delete(userId);
      
      // Clean up empty room
      if (roomTyping.size === 0) {
        this.typingUsers.delete(roomId);
      }

      // Emit stop typing event to other users in room
      socketServer.emitToRoomExcept(roomId, userId, 'userTyping', {
        roomId,
        userId,
        userName: typingData.userName,
        isTyping: false,
        timestamp: new Date().toISOString()
      });

      logger.debug('Typing Service - Stopped', { roomId, userId, userName: typingData.userName });
      
      return true;
    } catch (error) {
      logger.error('Typing Service - Stop Error', { error: error.message, roomId, userId });
      return false;
    }
  }

  // Get currently typing users in a room
  getTypingUsers(roomId) {
    try {
      const roomTyping = this.typingUsers.get(roomId);
      if (!roomTyping) {
        return [];
      }

      const typingUsers = [];
      for (const [userId, data] of roomTyping) {
        typingUsers.push({
          userId,
          userName: data.userName,
          startTime: data.startTime
        });
      }

      return typingUsers;
    } catch (error) {
      logger.error('Typing Service - Get Typing Users Error', { error: error.message, roomId });
      return [];
    }
  }

  // Check if user is typing in a room
  isUserTyping(roomId, userId) {
    const roomTyping = this.typingUsers.get(roomId);
    return roomTyping ? roomTyping.has(userId) : false;
  }

  // Clear all typing indicators for a user (when they disconnect)
  clearUserTyping(userId, socketServer) {
    try {
      for (const [roomId, roomTyping] of this.typingUsers) {
        if (roomTyping.has(userId)) {
          this.stopTyping(roomId, userId, socketServer);
        }
      }
      
      logger.debug('Typing Service - Cleared User Typing', { userId });
    } catch (error) {
      logger.error('Typing Service - Clear User Typing Error', { error: error.message, userId });
    }
  }

  // Clear all typing indicators for a room
  clearRoomTyping(roomId, socketServer) {
    try {
      const roomTyping = this.typingUsers.get(roomId);
      if (!roomTyping) return;

      // Stop typing for all users in room
      for (const userId of roomTyping.keys()) {
        this.stopTyping(roomId, userId, socketServer);
      }

      logger.debug('Typing Service - Cleared Room Typing', { roomId });
    } catch (error) {
      logger.error('Typing Service - Clear Room Typing Error', { error: error.message, roomId });
    }
  }

  // Get typing statistics
  getTypingStats() {
    const stats = {
      totalRooms: this.typingUsers.size,
      totalTypingUsers: 0,
      roomBreakdown: {}
    };

    for (const [roomId, roomTyping] of this.typingUsers) {
      const typingCount = roomTyping.size;
      stats.totalTypingUsers += typingCount;
      stats.roomBreakdown[roomId] = {
        typingUsers: typingCount,
        users: Array.from(roomTyping.keys())
      };
    }

    return stats;
  }

  // Cleanup expired typing indicators
  cleanup() {
    try {
      const now = new Date();
      let cleanedCount = 0;

      for (const [roomId, roomTyping] of this.typingUsers) {
        for (const [userId, data] of roomTyping) {
          // If typing for more than 30 seconds, auto-clear
          if (now - data.startTime > 30000) {
            clearTimeout(data.timer);
            roomTyping.delete(userId);
            cleanedCount++;
          }
        }

        // Remove empty rooms
        if (roomTyping.size === 0) {
          this.typingUsers.delete(roomId);
        }
      }

      if (cleanedCount > 0) {
        logger.info('Typing Service - Cleanup', { cleanedIndicators: cleanedCount });
      }
    } catch (error) {
      logger.error('Typing Service - Cleanup Error', { error: error.message });
    }
  }
}

// Create singleton instance
const typingService = new TypingService();

// Run cleanup every minute
setInterval(() => {
  typingService.cleanup();
}, 60000);

module.exports = typingService;
