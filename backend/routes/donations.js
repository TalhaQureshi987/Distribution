const express = require("express");
const router = express.Router();

const {
  createDonation,
  getAvailableDonations,
  getDonationById,
  getUserDonations,
  reserveDonation,
  updateDonationStatus,
  deleteDonation,
  getDonationsByStatus,
  getUrgentDonations,
} = require("../controllers/donationController");

const { protect } = require("../middleware/authMiddleware");

// Create donation
router.post("/", protect, createDonation);

// List available donations
router.get("/", protect, getAvailableDonations);

// My donations
router.get("/my-donations", protect, getUserDonations);

// Urgent donations
router.get("/urgent", protect, getUrgentDonations);

// Donations by status
router.get("/status/:status", protect, getDonationsByStatus);

// Single donation (must be last to avoid conflicts)
router.get("/:id", protect, getDonationById);

// Reserve donation
router.patch("/:id/reserve", protect, reserveDonation);

// Update donation status
router.patch("/:id/status", protect, updateDonationStatus);

// Delete donation
router.delete("/:id", protect, deleteDonation);

module.exports = router;
