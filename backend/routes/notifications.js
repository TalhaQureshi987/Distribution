const express = require("express");
const router = express.Router();

const {
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
  getUnreadCount,
  createNotification,
} = require("../controllers/notificationController");

const { protect } = require("../middleware/authMiddleware");

// User notification routes
router.get("/", protect, getUserNotifications);
router.get("/unread-count", protect, getUnreadCount);
router.patch("/:id/read", protect, markNotificationAsRead);
router.patch("/read-all", protect, markAllNotificationsAsRead);
router.delete("/:id", protect, deleteNotification);

// Internal route for creating notifications
router.post("/", protect, createNotification);

module.exports = router;
