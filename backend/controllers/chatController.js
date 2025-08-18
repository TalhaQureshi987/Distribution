const ChatRoom = require("../models/ChatRoom");
const ChatMessage = require("../models/ChatMessage");
const User = require("../models/User");
const { validateMessage } = require("../validators/chatValidator");

// @desc    Create or get chat room between two users
// @route   POST /api/chat/rooms
// @access  Private
const createOrGetChatRoom = async (req, res) => {
  try {
    const { otherUserId, otherUserName, donationId, requestId } = req.body;

    if (!otherUserId || !otherUserName) {
      return res
        .status(400)
        .json({ message: "Other user ID and name are required" });
    }

    // Check if other user exists
    const otherUser = await User.findById(otherUserId);
    if (!otherUser) {
      return res.status(404).json({ message: "Other user not found" });
    }

    // Check if chat room already exists
    let existingRoom = await ChatRoom.findOne({
      $or: [
        {
          participant1Id: req.user.id,
          participant2Id: otherUserId,
        },
        {
          participant1Id: otherUserId,
          participant2Id: req.user.id,
        },
      ],
    });

    if (existingRoom) {
      // Update room with donation/request context if provided
      if (donationId || requestId) {
        existingRoom.donationId = donationId || existingRoom.donationId;
        existingRoom.requestId = requestId || existingRoom.requestId;
        await existingRoom.save();
      }

      return res.json({ room: existingRoom });
    }

    // Create new chat room
    const newRoom = new ChatRoom({
      participant1Id: req.user.id,
      participant1Name: req.user.name,
      participant2Id: otherUserId,
      participant2Name: otherUserName,
      donationId,
      requestId,
    });

    const savedRoom = await newRoom.save();

    res.status(201).json({ room: savedRoom });
  } catch (error) {
    console.error("Error creating/getting chat room:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get user's chat rooms
// @route   GET /api/chat/rooms
// @access  Private
const getChatRooms = async (req, res) => {
  try {
    const rooms = await ChatRoom.find({
      $or: [{ participant1Id: req.user.id }, { participant2Id: req.user.id }],
    }).sort({ lastMessageAt: -1, createdAt: -1 });

    // Get last message and unread count for each room
    const roomsWithDetails = await Promise.all(
      rooms.map(async (room) => {
        const lastMessage = await ChatMessage.findOne({
          roomId: room._id,
        }).sort({ timestamp: -1 });

        const unreadCount = await ChatMessage.countDocuments({
          roomId: room._id,
          receiverId: req.user.id,
          isRead: false,
        });

        room.lastMessage = lastMessage?.message || null;
        room.lastMessageAt = lastMessage?.timestamp || room.createdAt;
        room.unreadCount = unreadCount;

        return room;
      })
    );

    res.json({ rooms: roomsWithDetails });
  } catch (error) {
    console.error("Error fetching chat rooms:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get messages for a specific chat room
// @route   GET /api/chat/rooms/:roomId/messages
// @access  Private
const getRoomMessages = async (req, res) => {
  try {
    const { roomId } = req.params;
    const { page = 1, limit = 50 } = req.query;

    // Verify user is part of this chat room
    const room = await ChatRoom.findById(roomId);
    if (!room) {
      return res.status(404).json({ message: "Chat room not found" });
    }

    if (
      room.participant1Id.toString() !== req.user.id &&
      room.participant2Id.toString() !== req.user.id
    ) {
      return res
        .status(403)
        .json({ message: "Not authorized to access this chat room" });
    }

    const skip = (page - 1) * limit;

    const messages = await ChatMessage.find({ roomId })
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await ChatMessage.countDocuments({ roomId });

    // Mark messages as read
    await ChatMessage.updateMany(
      {
        roomId,
        receiverId: req.user.id,
        isRead: false,
      },
      { isRead: true }
    );

    res.json({
      messages: messages.reverse(), // Return in chronological order
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching room messages:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Send a message
// @route   POST /api/chat/rooms/:roomId/messages
// @access  Private
const sendMessage = async (req, res) => {
  try {
    const { roomId } = req.params;
    const {
      message,
      messageType = "text",
      imageUrl,
      latitude,
      longitude,
      replyTo,
    } = req.body;

    if (!message && messageType === "text") {
      return res.status(400).json({ message: "Message content is required" });
    }

    // Verify user is part of this chat room
    const room = await ChatRoom.findById(roomId);
    if (!room) {
      return res.status(404).json({ message: "Chat room not found" });
    }

    if (
      room.participant1Id.toString() !== req.user.id &&
      room.participant2Id.toString() !== req.user.id
    ) {
      return res
        .status(403)
        .json({ message: "Not authorized to send message to this chat room" });
    }

    // Determine receiver
    const receiverId =
      room.participant1Id.toString() === req.user.id
        ? room.participant2Id
        : room.participant1Id;

    const receiverName =
      room.participant1Id.toString() === req.user.id
        ? room.participant2Name
        : room.participant1Name;

    // Create message
    const newMessage = new ChatMessage({
      roomId,
      senderId: req.user.id,
      senderName: req.user.name,
      receiverId,
      receiverName,
      message: message || "",
      messageType,
      imageUrl,
      latitude,
      longitude,
      replyTo,
    });

    const savedMessage = await newMessage.save();

    // Update chat room's last message info
    room.lastMessage = message || "";
    room.lastMessageAt = new Date();
    await room.save();

    // Emit to Socket.IO if connected
    if (req.app.locals.io) {
      req.app.locals.io.to(roomId).emit("new_message", {
        message: savedMessage,
        roomId,
      });
    }

    res.status(201).json({ message: savedMessage });
  } catch (error) {
    console.error("Error sending message:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Mark messages as read
// @route   PATCH /api/chat/rooms/:roomId/read
// @access  Private
const markMessagesAsRead = async (req, res) => {
  try {
    const { roomId } = req.params;

    // Verify user is part of this chat room
    const room = await ChatRoom.findById(roomId);
    if (!room) {
      return res.status(404).json({ message: "Chat room not found" });
    }

    if (
      room.participant1Id.toString() !== req.user.id &&
      room.participant2Id.toString() !== req.user.id
    ) {
      return res
        .status(403)
        .json({ message: "Not authorized to access this chat room" });
    }

    // Mark all unread messages as read
    const result = await ChatMessage.updateMany(
      {
        roomId,
        receiverId: req.user.id,
        isRead: false,
      },
      { isRead: true }
    );

    res.json({
      message: "Messages marked as read",
      updatedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error("Error marking messages as read:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Delete a message
// @route   DELETE /api/chat/rooms/:roomId/messages/:messageId
// @access  Private
const deleteMessage = async (req, res) => {
  try {
    const { roomId, messageId } = req.params;

    // Verify user is part of this chat room
    const room = await ChatRoom.findById(roomId);
    if (!room) {
      return res.status(404).json({ message: "Chat room not found" });
    }

    if (
      room.participant1Id.toString() !== req.user.id &&
      room.participant2Id.toString() !== req.user.id
    ) {
      return res
        .status(403)
        .json({ message: "Not authorized to access this chat room" });
    }

    // Find and verify message ownership
    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    if (message.senderId.toString() !== req.user.id) {
      return res
        .status(403)
        .json({ message: "Can only delete your own messages" });
    }

    await ChatMessage.findByIdAndDelete(messageId);

    // Emit to Socket.IO if connected
    if (req.app.locals.io) {
      req.app.locals.io.to(roomId).emit("message_deleted", {
        messageId,
        roomId,
      });
    }

    res.json({ message: "Message deleted successfully" });
  } catch (error) {
    console.error("Error deleting message:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get unread message count
// @route   GET /api/chat/unread-count
// @access  Private
const getUnreadCount = async (req, res) => {
  try {
    const unreadCount = await ChatMessage.countDocuments({
      receiverId: req.user.id,
      isRead: false,
    });

    res.json({ unreadCount });
  } catch (error) {
    console.error("Error fetching unread count:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Search messages
// @route   GET /api/chat/search
// @access  Private
const searchMessages = async (req, res) => {
  try {
    const { query, roomId } = req.query;

    if (!query) {
      return res.status(400).json({ message: "Search query is required" });
    }

    let searchFilter = {
      $or: [
        { message: { $regex: query, $options: "i" } },
        { senderName: { $regex: query, $options: "i" } },
      ],
    };

    // If roomId is provided, search only in that room
    if (roomId) {
      // Verify user is part of this chat room
      const room = await ChatRoom.findById(roomId);
      if (!room) {
        return res.status(404).json({ message: "Chat room not found" });
      }

      if (
        room.participant1Id.toString() !== req.user.id &&
        room.participant2Id.toString() !== req.user.id
      ) {
        return res
          .status(403)
          .json({ message: "Not authorized to search in this chat room" });
      }

      searchFilter.roomId = roomId;
    } else {
      // Search in all user's chat rooms
      const userRooms = await ChatRoom.find({
        $or: [{ participant1Id: req.user.id }, { participant2Id: req.user.id }],
      });

      const roomIds = userRooms.map((room) => room._id);
      searchFilter.roomId = { $in: roomIds };
    }

    const messages = await ChatMessage.find(searchFilter)
      .sort({ timestamp: -1 })
      .limit(20)
      .populate("roomId", "participant1Name participant2Name");

    res.json({ messages });
  } catch (error) {
    console.error("Error searching messages:", error);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  createOrGetChatRoom,
  getChatRooms,
  getRoomMessages,
  sendMessage,
  markMessagesAsRead,
  deleteMessage,
  getUnreadCount,
  searchMessages,
};
