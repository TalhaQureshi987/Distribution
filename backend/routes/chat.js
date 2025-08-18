const express = require("express");
const router = express.Router();

const {
  createOrGetChatRoom,
  getChatRooms,
  getRoomMessages,
  sendMessage,
  markMessagesAsRead,
  deleteMessage,
  getUnreadCount,
  searchMessages,
} = require("../controllers/chatController");

const { protect } = require("../middleware/authMiddleware");

// Create or get chat room
router.post("/rooms", protect, createOrGetChatRoom);

// Get chat rooms
router.get("/rooms", protect, getChatRooms);

// Get room messages
router.get("/rooms/:roomId/messages", protect, getRoomMessages);

// Send message
router.post("/rooms/:roomId/messages", protect, sendMessage);

// Mark as read
router.patch("/rooms/:roomId/read", protect, markMessagesAsRead);

// Delete message
router.delete("/rooms/:roomId/messages/:messageId", protect, deleteMessage);

// Unread count
router.get("/unread-count", protect, getUnreadCount);

// Search messages
router.get("/search", protect, searchMessages);

module.exports = router;
