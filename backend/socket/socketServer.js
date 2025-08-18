const socketIO = require("socket.io");
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const ChatRoom = require("../models/ChatRoom");
const ChatMessage = require("../models/ChatMessage");

class SocketServer {
  constructor(server) {
    this.io = socketIO(server, {
      cors: {
        origin: process.env.FRONTEND_URL || "http://localhost:3000",
        methods: ["GET", "POST"],
      },
    });

    this.connectedUsers = new Map(); // userId -> socketId
    this.userSockets = new Map(); // socketId -> userId

    this.setupMiddleware();
    this.setupEventHandlers();
  }

  setupMiddleware() {
    // Authentication middleware
    this.io.use(async (socket, next) => {
      try {
        const token =
          socket.handshake.auth.token || socket.handshake.headers.authorization;

        if (!token) {
          return next(new Error("Authentication error: No token provided"));
        }

        // Remove 'Bearer ' prefix if present
        const cleanToken = token.replace("Bearer ", "");

        const decoded = jwt.verify(cleanToken, process.env.JWT_SECRET);
        const user = await User.findById(decoded.id).select(
          "id name email role"
        );

        if (!user) {
          return next(new Error("Authentication error: User not found"));
        }

        socket.user = user;
        next();
      } catch (error) {
        console.error("Socket authentication error:", error);
        next(new Error("Authentication error: Invalid token"));
      }
    });
  }

  setupEventHandlers() {
    this.io.on("connection", (socket) => {
      console.log(`User connected: ${socket.user.name} (${socket.user.id})`);

      // Store user connection
      this.connectedUsers.set(socket.user.id, socket.id);
      this.userSockets.set(socket.id, socket.user.id);

      // Join user to their personal room
      socket.join(`user_${socket.user.id}`);

      // Join user to their chat rooms
      this.joinUserToChatRooms(socket);

      // Handle joining specific chat room
      socket.on("join_room", (roomId) => {
        this.handleJoinRoom(socket, roomId);
      });

      // Handle leaving specific chat room
      socket.on("leave_room", (roomId) => {
        this.handleLeaveRoom(socket, roomId);
      });

      // Handle typing indicator
      socket.on("typing_start", (data) => {
        this.handleTypingStart(socket, data);
      });

      socket.on("typing_stop", (data) => {
        this.handleTypingStop(socket, data);
      });

      // Handle message delivery confirmation
      socket.on("message_delivered", (data) => {
        this.handleMessageDelivered(socket, data);
      });

      // Handle message read confirmation
      socket.on("message_read", (data) => {
        this.handleMessageRead(socket, data);
      });

      // Handle user status changes
      socket.on("user_status", (status) => {
        this.handleUserStatus(socket, status);
      });

      // Handle disconnect
      socket.on("disconnect", () => {
        this.handleDisconnect(socket);
      });

      // Handle errors
      socket.on("error", (error) => {
        console.error("Socket error:", error);
      });
    });
  }

  async joinUserToChatRooms(socket) {
    try {
      const chatRooms = await ChatRoom.find({
        $or: [
          { participant1Id: socket.user.id },
          { participant2Id: socket.user.id },
        ],
      });

      chatRooms.forEach((room) => {
        socket.join(room._id.toString());
        console.log(`User ${socket.user.name} joined room: ${room._id}`);
      });
    } catch (error) {
      console.error("Error joining user to chat rooms:", error);
    }
  }

  async handleJoinRoom(socket, roomId) {
    try {
      // Verify user is part of this chat room
      const room = await ChatRoom.findById(roomId);
      if (!room) {
        socket.emit("error", { message: "Chat room not found" });
        return;
      }

      if (
        room.participant1Id.toString() !== socket.user.id &&
        room.participant2Id.toString() !== socket.user.id
      ) {
        socket.emit("error", {
          message: "Not authorized to join this chat room",
        });
        return;
      }

      socket.join(roomId);
      console.log(`User ${socket.user.name} joined room: ${roomId}`);

      // Notify other users in the room
      socket.to(roomId).emit("user_joined_room", {
        userId: socket.user.id,
        userName: socket.user.name,
        roomId,
      });

      // Mark messages as read
      await ChatMessage.updateMany(
        {
          roomId,
          receiverId: socket.user.id,
          isRead: false,
        },
        { isRead: true }
      );

      // Emit unread count update
      this.emitUnreadCountUpdate(socket.user.id);
    } catch (error) {
      console.error("Error joining room:", error);
      socket.emit("error", { message: "Error joining room" });
    }
  }

  handleLeaveRoom(socket, roomId) {
    socket.leave(roomId);
    console.log(`User ${socket.user.name} left room: ${roomId}`);

    // Notify other users in the room
    socket.to(roomId).emit("user_left_room", {
      userId: socket.user.id,
      userName: socket.user.name,
      roomId,
    });
  }

  handleTypingStart(socket, data) {
    const { roomId } = data;

    // Emit typing indicator to other users in the room
    socket.to(roomId).emit("user_typing", {
      userId: socket.user.id,
      userName: socket.user.name,
      roomId,
      isTyping: true,
    });
  }

  handleTypingStop(socket, data) {
    const { roomId } = data;

    // Emit typing stop indicator to other users in the room
    socket.to(roomId).emit("user_typing", {
      userId: socket.user.id,
      userName: socket.user.name,
      roomId,
      isTyping: false,
    });
  }

  async handleMessageDelivered(socket, data) {
    const { messageId, roomId } = data;

    try {
      // Update message delivery status
      await ChatMessage.findByIdAndUpdate(messageId, {
        isDelivered: true,
        deliveredAt: new Date(),
      });

      // Emit delivery confirmation to sender
      socket.to(roomId).emit("message_delivered", {
        messageId,
        roomId,
        deliveredAt: new Date(),
      });
    } catch (error) {
      console.error("Error updating message delivery status:", error);
    }
  }

  async handleMessageRead(socket, data) {
    const { messageId, roomId } = data;

    try {
      // Update message read status
      await ChatMessage.findByIdAndUpdate(messageId, {
        isRead: true,
        readAt: new Date(),
      });

      // Emit read confirmation to sender
      socket.to(roomId).emit("message_read", {
        messageId,
        roomId,
        readAt: new Date(),
      });

      // Update unread count for sender
      this.emitUnreadCountUpdate(socket.user.id);
    } catch (error) {
      console.error("Error updating message read status:", error);
    }
  }

  handleUserStatus(socket, status) {
    // Broadcast user status change to all connected users
    this.io.emit("user_status_changed", {
      userId: socket.user.id,
      userName: socket.user.name,
      status,
      timestamp: new Date(),
    });
  }

  handleDisconnect(socket) {
    console.log(`User disconnected: ${socket.user.name} (${socket.user.id})`);

    // Remove user from connected users maps
    this.connectedUsers.delete(socket.user.id);
    this.userSockets.delete(socket.id);

    // Broadcast user offline status
    this.io.emit("user_offline", {
      userId: socket.user.id,
      userName: socket.user.name,
      timestamp: new Date(),
    });
  }

  // Public methods for external use
  emitToUser(userId, event, data) {
    const socketId = this.connectedUsers.get(userId);
    if (socketId) {
      this.io.to(socketId).emit(event, data);
    }
  }

  emitToRoom(roomId, event, data) {
    this.io.to(roomId).emit(event, data);
  }

  emitToAll(event, data) {
    this.io.emit(event, data);
  }

  async emitUnreadCountUpdate(userId) {
    try {
      const unreadCount = await ChatMessage.countDocuments({
        receiverId: userId,
        isRead: false,
      });

      this.emitToUser(userId, "unread_count_update", { unreadCount });
    } catch (error) {
      console.error("Error emitting unread count update:", error);
    }
  }

  // Get connected users count
  getConnectedUsersCount() {
    return this.connectedUsers.size;
  }

  // Check if user is online
  isUserOnline(userId) {
    return this.connectedUsers.has(userId);
  }

  // Get user's socket ID
  getUserSocketId(userId) {
    return this.connectedUsers.get(userId);
  }
}

module.exports = SocketServer;
