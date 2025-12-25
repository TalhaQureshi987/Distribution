const express = require("express");
const router = express.Router();

const {
  getAvailableDeliveries,
  acceptDelivery,
  getDeliveryDashboardStats,
  createDeliveryOffer,
  approveDeliveryOffer
} = require("../controllers/deliveryController");
const { protect, admin } = require('../middleware/authMiddleware');
const { requireDelivery, requireApprovedStatus } = require('../middleware/roleMiddleware');

// -----------------------------------------------------------------------------
// DELIVERY & EARNING SYSTEM (UNIFIED)
// -----------------------------------------------------------------------------

// Get available delivery opportunities with earning potential
router.get("/available", protect, requireDelivery, getAvailableDeliveries);

// Accept a delivery assignment (start earning process)
router.post("/:deliveryId/accept", protect, requireDelivery, acceptDelivery);

// Enhanced delivery acceptance route with full notification system
router.post("/:deliveryId/accept-enhanced", protect, requireDelivery, acceptDeliveryEnhanced);

// Get my deliveries with earning status
router.get("/my-deliveries", protect, requireDelivery, getMyDeliveries);

// Update delivery status (triggers earning when completed)
router.patch("/:deliveryId/status", protect, requireDelivery, updateDeliveryStatus);

// Get my earnings from deliveries
router.get("/my-earnings", protect, requireDelivery, getMyEarnings);

// Request payout of earned money
router.post("/request-payout", protect, requireDelivery, requestPayout);

// Get delivery dashboard statistics
router.get('/dashboard-stats', protect, getDeliveryDashboardStats);

// Get delivery user's activities
router.get("/activities/:userId", protect, requireDelivery, getDeliveryActivities);

// Create delivery offer for a specific donation/request
router.post('/offer/:deliveryType/:itemId', protect, requireDelivery, createDeliveryOffer);

// Approve delivery offer
router.post('/approve-offer/:offerId', protect, approveDeliveryOffer);

// Get pending delivery offers
router.get('/pending-offers', protect, getPendingDeliveryOffers);

// -----------------------------------------------------------------------------
// ADMIN DELIVERY ROUTES
// -----------------------------------------------------------------------------

// Delivery management routes
router.get('/admin/all', protect, admin, getAllDeliveries);
router.get('/admin/analytics', protect, admin, getDeliveryAnalytics);
router.get('/admin/personnel', protect, admin, getDeliveryPersonnel);

// Delivery actions
router.patch('/admin/:deliveryId/cancel', protect, admin, cancelDelivery);

// Payout management routes
router.get('/admin/payouts', protect, admin, getAllPayoutRequests);
router.patch('/admin/payouts/:earningId/approve', protect, admin, approvePayoutRequest);
router.patch('/admin/payouts/:earningId/reject', protect, admin, rejectPayoutRequest);

// Commission management routes
router.get('/admin/commission-settings', protect, admin, getCommissionSettings);
router.patch('/admin/commission-settings', protect, admin, updateCommissionSettings);
router.get('/admin/company-earnings', protect, admin, getCompanyEarnings);
router.get('/admin/registration-commissions', protect, admin, getRegistrationCommissions);

module.exports = router;
