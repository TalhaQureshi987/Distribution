const { logger } = require('../utils/logger');
const ChatMessage = require('../models/ChatMessage');

class ReadReceiptService {
  constructor() {
    this.pendingReceipts = new Map(); // messageId -> { roomId, senderId, timestamp }
  }

  // Mark message as delivered
  async markAsDelivered(messageId, userId, socketServer) {
    try {
      const message = await ChatMessage.findById(messageId);
      if (!message) {
        logger.warn('Read Receipt - Message not found for delivery', { messageId, userId });
        return false;
      }

      // Only mark as delivered if user is the receiver
      if (message.receiverId.toString() !== userId) {
        logger.warn('Read Receipt - Unauthorized delivery attempt', { messageId, userId, receiverId: message.receiverId });
        return false;
      }

      // Update message delivery status
      if (!message.isDelivered) {
        message.isDelivered = true;
        message.deliveredAt = new Date();
        await message.save();

        // Emit delivery receipt to sender
        socketServer.emitToUser(message.senderId.toString(), 'messageDelivered', {
          messageId: message._id,
          roomId: message.roomId,
          deliveredAt: message.deliveredAt,
          deliveredTo: userId
        });

        logger.info('Read Receipt - Message Delivered', { 
          messageId, 
          senderId: message.senderId, 
          receiverId: userId,
          roomId: message.roomId 
        });
      }

      return true;
    } catch (error) {
      logger.error('Read Receipt - Delivery Error', { error: error.message, messageId, userId });
      return false;
    }
  }

  // Mark message as read
  async markAsRead(messageId, userId, socketServer) {
    try {
      const message = await ChatMessage.findById(messageId);
      if (!message) {
        logger.warn('Read Receipt - Message not found for read', { messageId, userId });
        return false;
      }

      // Only mark as read if user is the receiver
      if (message.receiverId.toString() !== userId) {
        logger.warn('Read Receipt - Unauthorized read attempt', { messageId, userId, receiverId: message.receiverId });
        return false;
      }

      // Update message read status
      if (!message.isRead) {
        message.isRead = true;
        message.readAt = new Date();
        
        // Also mark as delivered if not already
        if (!message.isDelivered) {
          message.isDelivered = true;
          message.deliveredAt = message.readAt;
        }
        
        await message.save();

        // Emit read receipt to sender
        socketServer.emitToUser(message.senderId.toString(), 'messageRead', {
          messageId: message._id,
          roomId: message.roomId,
          readAt: message.readAt,
          readBy: userId
        });

        logger.info('Read Receipt - Message Read', { 
          messageId, 
          senderId: message.senderId, 
          receiverId: userId,
          roomId: message.roomId 
        });
      }

      return true;
    } catch (error) {
      logger.error('Read Receipt - Read Error', { error: error.message, messageId, userId });
      return false;
    }
  }

  // Mark all messages in room as read by user
  async markRoomAsRead(roomId, userId, socketServer) {
    try {
      // Find all unread messages in room where user is receiver
      const unreadMessages = await ChatMessage.find({
        roomId,
        receiverId: userId,
        isRead: false
      }).select('_id senderId');

      if (unreadMessages.length === 0) {
        return { markedCount: 0 };
      }

      const messageIds = unreadMessages.map(msg => msg._id);
      const now = new Date();

      // Bulk update messages
      const updateResult = await ChatMessage.updateMany(
        {
          _id: { $in: messageIds },
          receiverId: userId,
          isRead: false
        },
        {
          $set: {
            isRead: true,
            readAt: now,
            isDelivered: true,
            deliveredAt: now
          }
        }
      );

      // Emit read receipts to senders
      const senderIds = [...new Set(unreadMessages.map(msg => msg.senderId.toString()))];
      
      for (const senderId of senderIds) {
        const senderMessages = unreadMessages
          .filter(msg => msg.senderId.toString() === senderId)
          .map(msg => msg._id);

        socketServer.emitToUser(senderId, 'messagesRead', {
          roomId,
          messageIds: senderMessages,
          readAt: now,
          readBy: userId,
          count: senderMessages.length
        });
      }

      logger.info('Read Receipt - Room Marked as Read', { 
        roomId, 
        userId, 
        markedCount: updateResult.modifiedCount 
      });

      return { markedCount: updateResult.modifiedCount };
    } catch (error) {
      logger.error('Read Receipt - Room Read Error', { error: error.message, roomId, userId });
      return { markedCount: 0, error: error.message };
    }
  }

  // Get read receipt status for messages
  async getReadReceiptStatus(messageIds, userId) {
    try {
      const messages = await ChatMessage.find({
        _id: { $in: messageIds },
        $or: [
          { senderId: userId },
          { receiverId: userId }
        ]
      }).select('_id senderId receiverId isDelivered deliveredAt isRead readAt');

      const receipts = {};
      
      for (const message of messages) {
        receipts[message._id] = {
          messageId: message._id,
          isDelivered: message.isDelivered,
          deliveredAt: message.deliveredAt,
          isRead: message.isRead,
          readAt: message.readAt,
          isSender: message.senderId.toString() === userId
        };
      }

      return receipts;
    } catch (error) {
      logger.error('Read Receipt - Get Status Error', { error: error.message, messageIds, userId });
      return {};
    }
  }

  // Get unread message count for user in room
  async getUnreadCount(roomId, userId) {
    try {
      const count = await ChatMessage.countDocuments({
        roomId,
        receiverId: userId,
        isRead: false
      });

      return count;
    } catch (error) {
      logger.error('Read Receipt - Get Unread Count Error', { error: error.message, roomId, userId });
      return 0;
    }
  }

  // Get total unread count for user across all rooms
  async getTotalUnreadCount(userId) {
    try {
      const count = await ChatMessage.countDocuments({
        receiverId: userId,
        isRead: false
      });

      return count;
    } catch (error) {
      logger.error('Read Receipt - Get Total Unread Count Error', { error: error.message, userId });
      return 0;
    }
  }

  // Get unread counts by room for user
  async getUnreadCountsByRoom(userId) {
    try {
      const pipeline = [
        {
          $match: {
            receiverId: userId,
            isRead: false
          }
        },
        {
          $group: {
            _id: '$roomId',
            unreadCount: { $sum: 1 },
            lastMessageAt: { $max: '$createdAt' }
          }
        },
        {
          $sort: { lastMessageAt: -1 }
        }
      ];

      const results = await ChatMessage.aggregate(pipeline);
      
      const unreadCounts = {};
      for (const result of results) {
        unreadCounts[result._id] = {
          roomId: result._id,
          unreadCount: result.unreadCount,
          lastMessageAt: result.lastMessageAt
        };
      }

      return unreadCounts;
    } catch (error) {
      logger.error('Read Receipt - Get Unread Counts by Room Error', { error: error.message, userId });
      return {};
    }
  }

  // Auto-mark messages as delivered when user comes online
  async autoMarkDelivered(userId, socketServer) {
    try {
      const undeliveredMessages = await ChatMessage.find({
        receiverId: userId,
        isDelivered: false
      }).select('_id senderId roomId');

      if (undeliveredMessages.length === 0) {
        return { markedCount: 0 };
      }

      const messageIds = undeliveredMessages.map(msg => msg._id);
      const now = new Date();

      // Bulk update messages as delivered
      const updateResult = await ChatMessage.updateMany(
        {
          _id: { $in: messageIds },
          receiverId: userId,
          isDelivered: false
        },
        {
          $set: {
            isDelivered: true,
            deliveredAt: now
          }
        }
      );

      // Emit delivery receipts to senders
      const senderIds = [...new Set(undeliveredMessages.map(msg => msg.senderId.toString()))];
      
      for (const senderId of senderIds) {
        const senderMessages = undeliveredMessages
          .filter(msg => msg.senderId.toString() === senderId)
          .map(msg => ({ messageId: msg._id, roomId: msg.roomId }));

        socketServer.emitToUser(senderId, 'messagesDelivered', {
          messages: senderMessages,
          deliveredAt: now,
          deliveredTo: userId,
          count: senderMessages.length
        });
      }

      logger.info('Read Receipt - Auto Marked as Delivered', { 
        userId, 
        markedCount: updateResult.modifiedCount 
      });

      return { markedCount: updateResult.modifiedCount };
    } catch (error) {
      logger.error('Read Receipt - Auto Mark Delivered Error', { error: error.message, userId });
      return { markedCount: 0, error: error.message };
    }
  }
}

// Create singleton instance
const readReceiptService = new ReadReceiptService();

module.exports = readReceiptService;
