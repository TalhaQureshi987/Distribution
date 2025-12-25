const express = require('express');
const router = express.Router();
const {
  getUserActivity,
  getUserDonations,
  getUserRequests,
  getUserStatistics,
  getUserPaymentStatistics,
  getUserPayments,
  getRoleBasedUserPayments,
} = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');

// Apply authentication middleware to all profile routes
router.use(protect);

// Routes
router.get('/:userId/activity', getUserActivity);
router.get('/:userId/donations', getUserDonations);
router.get('/:userId/requests', getUserRequests);
router.get('/:userId/statistics', getUserStatistics);
router.get('/:userId/payment-statistics', getUserPaymentStatistics);
router.get('/:userId/payments', getUserPayments);
router.get('/:userId/role-based-payments', getRoleBasedUserPayments);

module.exports = router;
