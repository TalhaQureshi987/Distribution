const express = require("express");
const router = express.Router();

const {
  updateProfile,
  changePassword,
  getProfile,
  deleteAccount,
} = require("../controllers/userController");

const { protect } = require("../middleware/authMiddleware");

// User profile routes
router.get("/profile", protect, getProfile);
router.put("/profile", protect, updateProfile);
router.put("/change-password", protect, changePassword);
router.delete("/profile", protect, deleteAccount);

module.exports = router;
