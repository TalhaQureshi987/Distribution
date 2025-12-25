const express = require('express');
const router = express.Router();
const { protect, admin } = require('../middleware/authMiddleware');
const {
  getPendingRequests,
  getRequestHistory,
  verifyRequest,
  rejectRequest,
  getRequestStats
} = require('../controllers/requestVerificationController');

// All routes require admin authentication
router.use(protect);
router.use(admin);

// Get pending requests for verification
router.get('/pending', getPendingRequests);

// Get request verification history
router.get('/history', getRequestHistory);

// Get request statistics
router.get('/stats', getRequestStats);

// Verify a request
router.put('/:requestId/verify', verifyRequest);

// Reject a request
router.put('/:requestId/reject', rejectRequest);

module.exports = router;
