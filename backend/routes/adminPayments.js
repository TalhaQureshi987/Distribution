const express = require('express');
const router = express.Router();

// Temporarily comment out the import to isolate the issue
try {
  const {
    getRevenueAnalytics,
    getDeliveryPayments,
    getCompanyPayments,
    getRoleBasedPayments,
    getUserPayments
  } = require('../controllers/adminPaymentController');
  
  const { protect } = require('../middleware/authMiddleware');
  const { admin } = require('../middleware/roleMiddleware');

  // Test if functions are properly imported
  console.log('Imported functions:', {
    getRevenueAnalytics: typeof getRevenueAnalytics,
    getDeliveryPayments: typeof getDeliveryPayments,
    getCompanyPayments: typeof getCompanyPayments,
    getRoleBasedPayments: typeof getRoleBasedPayments,
    getUserPayments: typeof getUserPayments
  });

  // Admin Routes
  if (getRevenueAnalytics) {
    router.get('/revenue-analytics', protect, admin, getRevenueAnalytics);
  }
  if (getDeliveryPayments) {
    router.get('/delivery-payments', protect, admin, getDeliveryPayments);
  }
  if (getCompanyPayments) {
    router.get('/company-payments', protect, admin, getCompanyPayments);
  }
  if (getRoleBasedPayments) {
    router.get('/role-based-payments', protect, admin, getRoleBasedPayments);
  }

  // User Routes (for profile screen)
  if (getUserPayments) {
    router.get('/user-payments', protect, getUserPayments);
  }
  
} catch (error) {
  console.error('Error importing adminPaymentController functions:', error);
  
  // Fallback routes that return empty data
  router.get('/revenue-analytics', (req, res) => {
    res.json({ success: false, message: 'Controller import error' });
  });
  router.get('/delivery-payments', (req, res) => {
    res.json({ success: false, message: 'Controller import error' });
  });
  router.get('/company-payments', (req, res) => {
    res.json({ success: false, message: 'Controller import error' });
  });
  router.get('/role-based-payments', (req, res) => {
    res.json({ success: false, message: 'Controller import error' });
  });
  router.get('/user-payments', (req, res) => {
    res.json({ success: false, message: 'Controller import error' });
  });
}

module.exports = router;
