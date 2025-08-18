const express = require("express");
const router = express.Router();

const {
  registerVolunteer,
  getVolunteerProfile,
  updateVolunteerProfile,
  getAllVolunteers,
  getVolunteerById,
  updateVolunteerStatus,
} = require("../controllers/volunteerController");

const { protect, admin } = require("../middleware/authMiddleware");

// Volunteer profile routes
router.post("/", protect, registerVolunteer);
router.get("/profile", protect, getVolunteerProfile);
router.put("/profile", protect, updateVolunteerProfile);

// Admin routes
router.get("/", protect, getAllVolunteers);
router.get("/:id", protect, getVolunteerById);
router.patch("/:id/status", protect, admin, updateVolunteerStatus);

module.exports = router;
