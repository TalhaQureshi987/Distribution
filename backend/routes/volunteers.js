const express = require("express");
const router = express.Router();

const {
  getVolunteerDashboardStats,
  getAvailableDeliveries,
  createVolunteerOffer,
  approveVolunteerOffer,
  rejectVolunteerOffer,
  getPendingVolunteerOffers,
  acceptVolunteerDelivery,
  getAcceptedVolunteerOffers,
  getAcceptedVolunteerOffersForDonors,
} = require("../controllers/volunteerController");

const { protect, admin } = require("../middleware/authMiddleware");
const {
  requireVolunteer,
  requireVolunteerWithVerification,
} = require("../middleware/roleMiddleware");

// Volunteer dashboard data routes
router.get("/dashboard-stats", protect, getVolunteerDashboardStats);
router.get("/available-deliveries", protect, getAvailableDeliveries);

// Volunteer offer routes
router.post(
  "/offer/:deliveryType/:itemId",
  protect,
  requireVolunteer,
  createVolunteerOffer
);
router.post("/approve-offer/:offerId", protect, approveVolunteerOffer);
router.post("/reject-offer/:offerId", protect, rejectVolunteerOffer);
router.get("/pending-offers", protect, getPendingVolunteerOffers);
router.get("/offers/for-approval", protect, getPendingVolunteerOffers);

// Enhanced volunteer delivery acceptance route
router.post(
  "/accept-delivery/:donationId",
  protect,
  requireVolunteer,
  acceptVolunteerDelivery
);

// Get accepted volunteer offers
router.get("/accepted-offers", protect, getAcceptedVolunteerOffers);

// Get accepted volunteer offers for donors (offers they've accepted)
router.get(
  "/accepted-offers-for-donors",
  protect,
  getAcceptedVolunteerOffersForDonors
);

module.exports = router;
