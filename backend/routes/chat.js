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
const validateObjectId = require("../middleware/validateObjectId");

// Create or get chat room
router.post("/rooms", protect, createOrGetChatRoom);

// Get chat rooms
router.get("/rooms", protect, getChatRooms);

// Get room messages
router.get("/rooms/:roomId/messages", protect, validateObjectId("roomId"), getRoomMessages);

// Send message
router.post("/rooms/:roomId/messages", protect, validateObjectId("roomId"), sendMessage);

// Mark as read
router.patch("/rooms/:roomId/read", protect, validateObjectId("roomId"), markMessagesAsRead);

// Delete message
router.delete(
  "/rooms/:roomId/messages/:messageId",
  protect,
  validateObjectId("roomId"),
  validateObjectId("messageId"),
  deleteMessage
);

// Unread count
router.get("/unread-count", protect, getUnreadCount);

// Search messages
router.get("/search", protect, searchMessages);

module.exports = router;
