const mongoose = require("mongoose");
const ChatRoom = require("../models/ChatRoom");
const ChatMessage = require("../models/ChatMessage");
const User = require("../models/User");
const { validateMessage } = require("../validators/chatValidator");

const toInt = (v, def) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : def;
};

// Helper function for ObjectId validation
const requireValidObjectId = (id, paramName) => {
  if (!id || String(id).trim() === '') {
    return { status: 400, message: `${paramName} is required` };
  }
  if (!mongoose.Types.ObjectId.isValid(String(id))) {
    return { status: 400, message: `Invalid ${paramName}` };
  }
  return null;
};

// @desc    Create or get chat room between two users
// @route   POST /api/chat/rooms
// @access  Private
const createOrGetChatRoom = async (req, res) => {
  try {
    const { otherUserId, otherUserName, donationId, requestId } = req.body;

    if (!otherUserId || !otherUserName) {
      return res.status(400).json({ message: "Other user ID and name are required" });
    }
    if (!mongoose.Types.ObjectId.isValid(otherUserId)) {
      return res.status(400).json({ message: "Invalid otherUserId" });
    }
    if (donationId && !mongoose.Types.ObjectId.isValid(donationId)) {
      return res.status(400).json({ message: "Invalid donationId" });
    }
    if (requestId && !mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(400).json({ message: "Invalid requestId" });
    }

    // Check if other user exists
    const otherUser = await User.findById(otherUserId).select("_id");
    if (!otherUser) {
      return res.status(404).json({ message: "Other user not found" });
    }

    // Check if chat room already exists (either ordering)
    const ids = [req.user.id, otherUserId].sort();
    let existingRoom = await ChatRoom.findOne({
      participant1Id: ids[0],
      participant2Id: ids[1],
    });
    

    if (existingRoom) {
      // Update room with donation/request context if provided
      let changed = false;
      if (donationId && (!existingRoom.donationId || existingRoom.donationId.toString() !== donationId)) {
        existingRoom.donationId = donationId;
        changed = true;
      }
      if (requestId && (!existingRoom.requestId || existingRoom.requestId.toString() !== requestId)) {
        existingRoom.requestId = requestId;
        changed = true;
      }
      if (changed) await existingRoom.save();
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
    // Fetch rooms
    const rooms = await ChatRoom.find({
      $or: [{ participant1Id: req.user.id }, { participant2Id: req.user.id }],
    })
      .sort({ lastMessageAt: -1, createdAt: -1 })
      .lean();

    if (!rooms.length) return res.json({ rooms: [] });

    const roomIds = rooms.map((r) => r._id);

    // Batch get last messages (avoid N+1)
    const lastMessages = await ChatMessage.aggregate([
      { $match: { roomId: { $in: roomIds } } },
      { $sort: { timestamp: -1 } },
      {
        $group: {
          _id: "$roomId",
          message: { $first: "$message" },
          messageType: { $first: "$messageType" },
          timestamp: { $first: "$timestamp" },
        },
      },
    ]);

    const lastMap = new Map(
      lastMessages.map((m) => [
        String(m._id),
        {
          message: m.messageType === "image" ? "[Image]" : m.messageType === "location" ? "[Location]" : m.message || "",
          timestamp: m.timestamp,
        },
      ])
    );

    // Batch unread counts
    const unreadAgg = await ChatMessage.aggregate([
      { $match: { roomId: { $in: roomIds }, receiverId: new mongoose.Types.ObjectId(req.user.id), isRead: false } },
      { $group: { _id: "$roomId", count: { $sum: 1 } } },
    ]);

    const unreadMap = new Map(unreadAgg.map((u) => [String(u._id), u.count]));

    const roomsWithDetails = rooms.map((room) => {
      const last = lastMap.get(String(room._id));
      return {
        ...room,
        id: room._id.toString(),
        lastMessage: last?.message || null,
        lastMessageAt: last?.timestamp || room.createdAt,
        unreadCount: unreadMap.get(String(room._id)) || 0,
      };
    });
    res.json({ rooms: roomsWithDetails });
  } catch (error) {
    console.error("Error fetching chat rooms:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get messages for a specific chat room
const getRoomMessages = async (req, res) => {
  try {
    console.log('[getRoomMessages] params=', req.params, 'query=', req.query, 'body=', req.body);
    const { roomId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    
    // Validate roomId
    const err = requireValidObjectId(roomId, 'roomId');
    if (err) return res.status(err.status).json({ message: err.message });

    // Check if user has access to this room
    const room = await ChatRoom.findById(roomId).select('participant1Id participant2Id');
    if (!room) {
      return res.status(404).json({ message: 'Chat room not found' });
    }

    const uid = String(req.user.id);
    if (String(room.participant1Id) !== uid && String(room.participant2Id) !== uid) {
      return res.status(403).json({ message: 'Not authorized to access this chat room' });
    }

    // Get messages with pagination
    const pageNum = toInt(page, 1);
    const limitNum = toInt(limit, 50);
    const skip = (pageNum - 1) * limitNum;

    const messages = await ChatMessage.find({ roomId })
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Reverse to show oldest first
    messages.reverse();

    res.json({ messages, page: pageNum, limit: limitNum });
  } catch (err) {
    console.error('Error fetching room messages:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Send a message
const sendMessage = async (req, res) => {
  try {
    const { roomId } = req.params;
    const { message, messageType = 'text', replyTo, imageUrl, latitude, longitude } = req.body;

    if (!message) return res.status(400).json({ message: "Message content is required" });

    // Validate roomId
    const err = requireValidObjectId(roomId, 'roomId');
    if (err) return res.status(err.status).json({ message: err.message });

    // Check if user has access to this room
    const room = await ChatRoom.findById(roomId).select('participant1Id participant2Id participant1Name participant2Name');
    if (!room) {
      return res.status(404).json({ message: 'Chat room not found' });
    }

    const uid = String(req.user.id);
    if (String(room.participant1Id) !== uid && String(room.participant2Id) !== uid) {
      return res.status(403).json({ message: 'Not authorized to send messages to this chat room' });
    }

    // Determine receiver
    const receiverId = String(room.participant1Id) === uid ? room.participant2Id : room.participant1Id;
    const receiverName = String(room.participant1Id) === uid ? room.participant2Name : room.participant1Name;

    const chatMessage = new ChatMessage({
      roomId,
      senderId: req.user.id,
      senderName: req.user.name,
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

    // Emit real-time via socket
    try {
      const { getIO } = require('../logic/socket');
      const io = getIO();
      
      // Emit to both participants' user rooms and the chat room
      io.to(`user_${req.user.id}`).emit('new_message', savedMessage);
      io.to(`user_${receiverId}`).emit('new_message', savedMessage);
      io.to(`room_${roomId}`).emit('new_message', savedMessage);
      
      console.log(`✅ Chat message emitted to user_${req.user.id}, user_${receiverId}, and room_${roomId}`);
    } catch (socketError) {
      console.error('❌ Socket emission failed:', socketError);
    }

    res.status(201).json({ message: savedMessage });
  } catch (error) {
    console.error("sendMessage error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Send a message
// @route   POST /api/chat/rooms/:roomId/messages
// @access  Private



// @desc    Mark messages as read
// @route   PATCH /api/chat/rooms/:roomId/read
// @access  Private
const markMessagesAsRead = async (req, res) => {
  try {
    const { roomId } = req.params;

    const room = await ChatRoom.findById(roomId).select("participant1Id participant2Id");
    if (!room) return res.status(404).json({ message: "Chat room not found" });

    const uid = String(req.user.id);
    if (String(room.participant1Id) !== uid && String(room.participant2Id) !== uid) {
      return res.status(403).json({ message: "Not authorized to access this chat room" });
    }

    const result = await ChatMessage.updateMany(
      { roomId, receiverId: req.user.id, isRead: false },
      { $set: { isRead: true, readAt: new Date() } }
    );

    res.json({ message: "Messages marked as read", updatedCount: result.modifiedCount });
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
    console.log(`[DELETE /rooms/:roomId/messages/:messageId] params:`, req.params);

    let err = requireValidObjectId(roomId, 'roomId');
    if (err) return res.status(err.status || 400).json({ message: err.message });
    err = requireValidObjectId(messageId, 'messageId');
    if (err) return res.status(err.status || 400).json({ message: err.message });

    const room = await ChatRoom.findById(roomId).select('participant1Id participant2Id');
    if (!room) return res.status(404).json({ message: 'Chat room not found' });

    // ... rest unchanged
  } catch (error) {
    console.error('Error deleting message:', error);
    res.status(500).json({ message: 'Server error' });
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

    if (!query) return res.status(400).json({ message: "Search query is required" });

    const filter = {
      $or: [
        { message: { $regex: query, $options: "i" } },
        { senderName: { $regex: query, $options: "i" } },
      ],
    };

    if (roomId) {
      if (!mongoose.Types.ObjectId.isValid(roomId)) {
        return res.status(400).json({ message: "Invalid roomId" });
      }
      const room = await ChatRoom.findById(roomId).select("participant1Id participant2Id");
      if (!room) return res.status(404).json({ message: "Chat room not found" });

      const uid = String(req.user.id);
      if (String(room.participant1Id) !== uid && String(room.participant2Id) !== uid) {
        return res.status(403).json({ message: "Not authorized to search in this chat room" });
      }

      filter.roomId = room._id;
    } else {
      // Search across all user's rooms
      const rooms = await ChatRoom.find({
        $or: [{ participant1Id: req.user.id }, { participant2Id: req.user.id }],
      }).select("_id");
      const roomIds = rooms.map((r) => r._id);
      if (!roomIds.length) return res.json({ messages: [] });
      filter.roomId = { $in: roomIds };
    }

    const messages = await ChatMessage.find(filter)
      .sort({ timestamp: -1 })
      .limit(20)
      .populate("roomId", "participant1Name participant2Name")
      .lean();

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
