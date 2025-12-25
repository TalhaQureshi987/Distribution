const express = require("express");
const router = express.Router();
const {
  createRegistrationPaymentIntent,
  confirmPaymentIntent,
  confirmPaymentEndpoint,
  createDonationPaymentIntent,
  createRequestPaymentIntent,
  getDeliveryRates,
  calculatePaymentPreview,
  processRegistrationFee,
  getPaidUsersWithDetails,
  getAllPayments,
  getDeliveryPayments,
  getRevenueAnalytics,
  confirmPayment,
  getPaymentStatus,
} = require("../controllers/paymentController");
const { protect, admin } = require("../middleware/authMiddleware");
const { requireApprovedRole } = require("../middleware/roleMiddleware");
const Donation = require("../models/Donation");
const Request = require("../models/Request");
const Delivery = require("../models/Delivery");
const Payment = require("../models/Payment");
const User = require("../models/User");
const { logger } = require("../utils/logger");

// Payment Intent Routes
router.post("/donation-payment-intent", protect, createDonationPaymentIntent);
router.post("/request-payment-intent", protect, createRequestPaymentIntent);
router.post(
  "/create-registration-payment-intent",
  createRegistrationPaymentIntent
);
router.post("/confirm-payment-intent", confirmPaymentIntent);
router.post("/confirm", protect, confirmPaymentEndpoint);

// Payment Confirmation Routes
router.post("/confirm-payment", protect, confirmPayment);
router.get("/status/:paymentIntentId", protect, getPaymentStatus);

// Registration fee
router.post("/registration-fee", protect, processRegistrationFee);

// Delivery rates
router.get("/delivery-rates", getDeliveryRates);
router.post("/calculate-preview", calculatePaymentPreview);

// Webhook

// Admin routes
router.get("/admin/all", protect, admin, getAllPayments);
router.get("/admin/paid-users", protect, admin, getPaidUsersWithDetails);
router.get("/admin/delivery-payments", protect, admin, getDeliveryPayments);

router.get("/admin/revenue-analytics", protect, admin, getRevenueAnalytics);

// Individual payment management

module.exports = router;
