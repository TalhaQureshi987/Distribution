// socket.js
const jwt = require('jsonwebtoken');
const ChatMessage = require('../models/ChatMessage');
const ChatRoom = require('../models/ChatRoom');
const config = require('../config/environment');
const { logger, socketLogger } = require('../utils/logger');
const userStatusService = require('../services/userStatusService');
const typingService = require('../services/typingService');
const readReceiptService = require('../services/readReceiptService');
const { validateMessage } = require('../validators/chatValidator');

let ioInstance = null;

function initSocket(server) {
  const { Server } = require('socket.io');
  const io = new Server(server, {
    cors: {
      origin: config.corsOrigins,
      methods: ['GET', 'POST'],
      credentials: true
    },
    pingTimeout: config.socket.pingTimeout,
    pingInterval: config.socket.pingInterval,
    transports: ['websocket', 'polling']
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || 
                   socket.handshake.headers['authorization'] ||
                   socket.handshake.query?.token;
      
      if (!token) {
        logger.warn('Socket Authentication - No token provided', {
          socketId: socket.id,
          ip: socket.handshake.address
        });
        return next(new Error('Authentication token required'));
      }

      // Clean and verify JWT token
      const cleanToken = token.replace('Bearer ', '');
      
      try {
        const decoded = jwt.verify(cleanToken, config.jwtSecret);
        socket.user = {
          id: decoded.userId || decoded.id, // Try userId first, fallback to id
          name: decoded.name || decoded.userName || 'Unknown User',
          email: decoded.email
        };
        
        logger.info('Socket Authentication - Success', {
          socketId: socket.id,
          userId: socket.user.id,
          userName: socket.user.name
        });
        
        next();
      } catch (jwtError) {
        logger.warn('Socket Authentication - Invalid token', {
          socketId: socket.id,
          error: jwtError.message,
          ip: socket.handshake.address
        });
        return next(new Error('Invalid authentication token'));
      }
    } catch (err) {
      const errorMessage = err?.message || 'Unknown error occurred';
      const errorStack = err?.stack || 'No stack trace available';
      
      logger.error('Socket Authentication - Unexpected error', {
        socketId: socket.id,
        error: errorMessage,
        stack: errorStack
      });
      next(new Error('Authentication error'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.user?.id;
    const userName = socket.user?.name;
    
    console.log(`🔌 New socket connection - User: ${userId}, Socket: ${socket.id}`);
    
    try {
      // Add user to status service
      await userStatusService.addConnection(socket.id, userId, userName);
      
      // Join user to their personal room for notifications
      const userRoom = `user_${userId}`;
      socket.join(userRoom);
      console.log(`🏠 User ${userId} joined personal room: ${userRoom}`);
      
      // Verify room membership
      const rooms = Array.from(socket.rooms);
      console.log(`📋 Socket ${socket.id} is in rooms: ${rooms.join(', ')}`);
      
      // Auto-mark messages as delivered when user comes online
      await readReceiptService.autoMarkDelivered(userId, {
        emitToUser: (targetUserId, event, data) => {
          io.to(`user_${targetUserId}`).emit(event, data);
        }
      });
      
      logger.info('Socket User Connected', {
        userId,
        socketId: socket.id,
        userRoom,
        rooms: rooms,
        context: 'connection'
      });
      
      // Emit user online status to relevant rooms
      const userRooms = await ChatRoom.find({
        $or: [
          { participant1Id: userId },
          { participant2Id: userId }
        ]
      }).select('_id participant1Id participant2Id');
      
      for (const room of userRooms) {
        const otherUserId = room.participant1Id.toString() === userId ? 
          room.participant2Id : room.participant1Id;
        
        io.to(`user_${otherUserId}`).emit('userStatusChanged', {
          userId,
          userName,
          status: 'online',
          timestamp: new Date()
        });
      }
    } catch (error) {
      const errorMessage = error?.message || 'Unknown error occurred';
      const errorStack = error?.stack || 'No stack trace available';
      
      logger.error('Socket Connection Setup Error', {
        userId,
        socketId: socket.id,
        error: errorMessage,
        stack: errorStack,
        context: 'connection_setup'
      });
    }

    // Join a chat room
    socket.on('join_room', async (roomId) => {
      try {
        if (!roomId || typeof roomId !== 'string') {
          socket.emit('error', { message: 'Valid room ID is required' });
          return;
        }

        // Verify user has access to this room
        const room = await ChatRoom.findById(roomId);
        if (!room) {
          socket.emit('error', { message: 'Chat room not found' });
          return;
        }

        const userIdStr = String(userId);
        if (String(room.participant1Id) !== userIdStr && String(room.participant2Id) !== userIdStr) {
          socket.emit('error', { message: 'Not authorized to join this room' });
          return;
        }

        socket.join(roomId);
        logger.info('Socket User Joined Room', {
          userId,
          socketId: socket.id,
          roomId
        });
        
        // Get current typing users in room
        const typingUsers = typingService.getTypingUsers(roomId);
        if (typingUsers.length > 0) {
          socket.emit('currentTypingUsers', { roomId, typingUsers });
        }
        
        // Notify room that user joined
        socket.to(roomId).emit('userJoined', {
          userId,
          userName,
          timestamp: new Date()
        });
        
        socket.emit('joinRoomSuccess', { roomId });
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Join Room Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'join_room'
        });
        socket.emit('error', { message: 'Failed to join room' });
      }
    });

    // Leave a chat room
    socket.on('leave_room', (roomId) => {
      try {
        if (!roomId || typeof roomId !== 'string') {
          socket.emit('error', { message: 'Valid room ID is required' });
          return;
        }

        socket.leave(roomId);
        logger.info('Socket User Left Room', {
          userId,
          socketId: socket.id,
          roomId
        });
        
        // Stop typing indicator if user was typing
        typingService.stopTyping(roomId, userId, {
          emitToRoomExcept: (targetRoomId, excludeUserId, event, data) => {
            socket.to(targetRoomId).emit(event, data);
          }
        });
        
        // Notify room that user left
        socket.to(roomId).emit('userLeft', {
          userId,
          userName,
          timestamp: new Date()
        });
        
        socket.emit('leaveRoomSuccess', { roomId });
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Leave Room Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'leave_room'
        });
        socket.emit('error', { message: 'Failed to leave room' });
      }
    });

    // Send message via socket (alternative to REST API)
    socket.on('sendMessage', async (data) => {
      try {
        // Validate message data
        const { error, value } = validateMessage(data);
        if (error) {
          socket.emit('error', { 
            message: 'Invalid message data', 
            details: error.details.map(d => d.message)
          });
          return;
        }

        const { roomId, message, messageType = 'text', replyTo, imageUrl, latitude, longitude } = value;
        
        if (!roomId) {
          socket.emit('error', { message: 'Room ID is required' });
          return;
        }

        // Verify user has access to this room
        const room = await ChatRoom.findById(roomId);
        if (!room) {
          socket.emit('error', { message: 'Chat room not found' });
          return;
        }

        const userIdStr = String(userId);
        if (String(room.participant1Id) !== userIdStr && String(room.participant2Id) !== userIdStr) {
          socket.emit('error', { message: 'Not authorized to send messages to this room' });
          return;
        }

        // Stop typing indicator
        typingService.stopTyping(roomId, userId, {
          emitToRoomExcept: (targetRoomId, excludeUserId, event, data) => {
            socket.to(targetRoomId).emit(event, data);
          }
        });

        // Determine receiver
        const receiverId = String(room.participant1Id) === userIdStr ? room.participant2Id : room.participant1Id;
        const receiverName = String(room.participant1Id) === userIdStr ? room.participant2Name : room.participant1Name;

        // Create and save message
        const chatMessage = new ChatMessage({
          roomId,
          senderId: userId,
          senderName: userName,
          receiverId,
          receiverName,
          message,
          messageType,
          replyTo,
          imageUrl,
          latitude,
          longitude,
          timestamp: new Date(),
        });

        const savedMessage = await chatMessage.save();

        // Update room's last message timestamp
        await ChatRoom.findByIdAndUpdate(roomId, {
          lastMessageAt: new Date()
        });

        // Emit to all users in the room
        io.to(roomId).emit('messageReceived', savedMessage);
        
        logger.info('Socket Message Sent', {
          userId,
          socketId: socket.id,
          roomId,
          messageType
        });
        
        socket.emit('messageSent', { messageId: savedMessage._id, roomId });
        
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Send Message Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'sendMessage'
        });
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // User status change
    socket.on('user_status', async (data) => {
      try {
        const { status } = data;
        
        if (!status || !['online', 'away', 'busy', 'offline'].includes(status)) {
          socket.emit('error', { message: 'Valid status is required (online, away, busy, offline)' });
          return;
        }

        const updatedStatus = await userStatusService.updateUserStatus(userId, status);
        
        // Emit status change to relevant users
        const userRooms = await ChatRoom.find({
          $or: [
            { participant1Id: userId },
            { participant2Id: userId }
          ]
        }).select('_id participant1Id participant2Id');
        
        for (const room of userRooms) {
          const otherUserId = room.participant1Id.toString() === userId ? 
            room.participant2Id : room.participant1Id;
          
          io.to(`user_${otherUserId}`).emit('userStatusChanged', {
            userId,
            userName,
            status: updatedStatus.status,
            timestamp: new Date()
          });
        }
        
        socket.emit('statusUpdateSuccess', updatedStatus);
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket User Status Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'user_status'
        });
        socket.emit('error', { message: 'Failed to update status' });
      }
    });

    // Mark messages as read
    socket.on('message_read', async (data) => {
      try {
        const { messageId, roomId } = data;
        
        if (messageId) {
          // Mark single message as read
          await readReceiptService.markAsRead(messageId, userId, {
            emitToUser: (targetUserId, event, data) => {
              io.to(`user_${targetUserId}`).emit(event, data);
            }
          });
        } else if (roomId) {
          // Mark all messages in room as read
          const result = await readReceiptService.markRoomAsRead(roomId, userId, {
            emitToUser: (targetUserId, event, data) => {
              io.to(`user_${targetUserId}`).emit(event, data);
            }
          });
          
          socket.emit('markAsReadSuccess', { roomId, count: result.markedCount });
        } else {
          socket.emit('error', { message: 'Message ID or Room ID is required' });
        }
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Mark Messages Read Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'message_read'
        });
        socket.emit('error', { message: 'Failed to mark messages as read' });
      }
    });

    // Mark message as delivered
    socket.on('message_delivered', async (data) => {
      try {
        const { messageId } = data;
        
        if (!messageId) {
          socket.emit('error', { message: 'Message ID is required' });
          return;
        }

        await readReceiptService.markAsDelivered(messageId, userId, {
          emitToUser: (targetUserId, event, data) => {
            io.to(`user_${targetUserId}`).emit(event, data);
          }
        });
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Mark Message Delivered Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'message_delivered'
        });
        socket.emit('error', { message: 'Failed to mark message as delivered' });
      }
    });

    // Typing indicator
    socket.on('typing', (data) => {
      try {
        const { roomId, isTyping } = data || {};
        
        if (!roomId || typeof roomId !== 'string') {
          socket.emit('error', { message: 'Valid room ID is required for typing' });
          return;
        }
        
        if (typeof isTyping !== 'boolean') {
          socket.emit('error', { message: 'isTyping must be a boolean' });
          return;
        }

        if (isTyping) {
          typingService.startTyping(roomId, userId, userName, {
            emitToRoomExcept: (targetRoomId, excludeUserId, event, data) => {
              socket.to(targetRoomId).emit(event, data);
            }
          });
        } else {
          typingService.stopTyping(roomId, userId, {
            emitToRoomExcept: (targetRoomId, excludeUserId, event, data) => {
              socket.to(targetRoomId).emit(event, data);
            }
          });
        }
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Typing Indicator Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'typing'
        });
        socket.emit('error', { message: 'Failed to handle typing indicator' });
      }
    });

    // Handle disconnect
    socket.on('disconnect', async () => {
      try {
        await userStatusService.removeConnection(socket.id);
        
        logger.info('Socket User Disconnected', {
          userId,
          socketId: socket.id,
          context: 'disconnect'
        });
      } catch (error) {
        const errorMessage = error?.message || 'Unknown error occurred';
        const errorStack = error?.stack || 'No stack trace available';
        
        logger.error('Socket Disconnect Error', {
          userId,
          socketId: socket.id,
          error: errorMessage,
          stack: errorStack,
          context: 'disconnect'
        });
      }
    });

    // Handle join_user_room event from frontend
    socket.on('join_user_room', (userId) => {
      try {
        const userRoom = `user_${userId}`;
        socket.join(userRoom);
        console.log(`🏠 User ${userId} manually joined room: ${userRoom} via join_user_room event`);
        
        // Verify room membership
        const rooms = Array.from(socket.rooms);
        console.log(`📋 Socket ${socket.id} rooms after manual join: ${rooms.join(', ')}`);
        
        logger.info('Socket Manual Room Join', {
          userId,
          socketId: socket.id,
          userRoom,
          rooms: rooms,
          context: 'manual_join'
        });
      } catch (error) {
        console.error(`❌ Error joining user room: ${error.message}`);
        logger.error('Socket Manual Room Join Error', {
          userId,
          socketId: socket.id,
          error: error.message,
          context: 'manual_join_error'
        });
      }
    });

    // Handle joinUser event from frontend
    socket.on('joinUser', (data) => {
      try {
        const targetUserId = data.userId;
        const userRoom = `user_${targetUserId}`;
        socket.join(userRoom);
        console.log(`🏠 User ${targetUserId} joined room: ${userRoom} via joinUser event`);
        
        // Verify room membership
        const rooms = Array.from(socket.rooms);
        console.log(`📋 Socket ${socket.id} rooms after joinUser: ${rooms.join(', ')}`);
        
        logger.info('Socket JoinUser Event', {
          userId,
          targetUserId,
          socketId: socket.id,
          userRoom,
          rooms: rooms,
          context: 'join_user_event'
        });
      } catch (error) {
        console.error(`❌ Error in joinUser event: ${error.message}`);
        logger.error('Socket JoinUser Event Error', {
          userId,
          socketId: socket.id,
          error: error.message,
          context: 'join_user_event_error'
        });
      }
    });
  });

  ioInstance = io;
  return io;
}

function getIO() {
  if (!ioInstance) {
    console.error('❌ Socket.IO not initialized. Call initSocket(server) first.');
    throw new Error('Socket.IO not initialized. Call initSocket(server) first.');
  }
  return ioInstance;
}

// Helper function to emit to a specific room
function emitToRoom(roomId, event, data) {
  if (ioInstance) {
    ioInstance.to(roomId).emit(event, data);
    logger.debug('Socket Emit to Room', { roomId, event, dataKeys: Object.keys(data || {}) });
  }
}

// Helper function to emit to a specific user
function emitToUser(userId, event, data) {
  if (ioInstance) {
    ioInstance.to(`user_${userId}`).emit(event, data);
    logger.debug('Socket Emit to User', { userId, event, dataKeys: Object.keys(data || {}) });
  }
}

// Helper function to emit to room except specific user
function emitToRoomExcept(roomId, excludeUserId, event, data) {
  if (ioInstance) {
    ioInstance.to(roomId).except(`user_${excludeUserId}`).emit(event, data);
    logger.debug('Socket Emit to Room Except User', { roomId, excludeUserId, event });
  }
}

// Get online users count
function getOnlineUsersCount() {
  return ioInstance ? ioInstance.sockets.sockets.size : 0;
}

// Get socket statistics
function getSocketStats() {
  if (!ioInstance) return null;
  
  return {
    connectedSockets: ioInstance.sockets.sockets.size,
    rooms: ioInstance.sockets.adapter.rooms.size,
    onlineUsers: userStatusService.getOnlineUsers().length,
    typingStats: typingService.getTypingStats()
  };
}

module.exports = { 
  initSocket, 
  getIO, 
  emitToRoom, 
  emitToUser, 
  emitToRoomExcept,
  getOnlineUsersCount,
  getSocketStats
};
