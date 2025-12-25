const express = require("express");
const router = express.Router();
const {
  createDeliveryOffer,
  getDeliveryOffersForApproval,
  approveDeliveryOffer,
  rejectDeliveryOffer,
  getAcceptedDeliveryOffersFromDonors,
  getAcceptedDeliveryOffersFromRequesters,
  getAcceptedDeliveryOffersForDonors,
  getVolunteerDashboardStats,
  debugAcceptedOffers,
} = require("../controllers/deliveryOfferController");
const { protect } = require("../middleware/authMiddleware");

// Create delivery offer (when volunteer/delivery person accepts)
router.post("/:itemType/:itemId/offer", protect, createDeliveryOffer);

// Get delivery offers for approval (for donors/requesters)
router.get("/for-approval", protect, getDeliveryOffersForApproval);

// Approve delivery offer
router.post("/:offerId/approve", protect, approveDeliveryOffer);

// Reject delivery offer
router.post("/:offerId/reject", protect, rejectDeliveryOffer);

// Get accepted delivery offers from donors
router.get(
  "/accepted-from-donors",
  protect,
  getAcceptedDeliveryOffersFromDonors
);

// Get accepted delivery offers from requesters
router.get(
  "/accepted-from-requesters",
  protect,
  getAcceptedDeliveryOffersFromRequesters
);

// Get accepted delivery offers for donors (for donors to see offers they've accepted)
router.get("/accepted-for-donors", protect, getAcceptedDeliveryOffersForDonors);

// Get accepted delivery offers (alias for accepted-from-donors)
router.get("/accepted", protect, getAcceptedDeliveryOffersFromDonors);

// Get volunteer dashboard stats
router.get("/volunteer-dashboard-stats", protect, getVolunteerDashboardStats);

// Debug endpoint
router.get("/debug-accepted-offers", protect, debugAcceptedOffers);

module.exports = router;
