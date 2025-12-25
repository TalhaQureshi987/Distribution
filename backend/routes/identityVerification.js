const express = require('express');
const router = express.Router();
const { protect, admin } = require('../middleware/authMiddleware');
const {
  sendEmailVerification,
  verifyEmailCode,
  uploadDocuments,
  getVerificationStatus,
  getPendingVerifications,
  approveVerification,
  rejectVerification
} = require('../controllers/identityVerificationController');

// User routes
router.post('/send-email-verification', protect, sendEmailVerification);
router.post('/verify-email', protect, verifyEmailCode);
router.post('/upload-documents', protect, uploadDocuments);
router.get('/status', protect, getVerificationStatus);

// Admin routes
router.get('/admin/pending', protect, admin, getPendingVerifications);
router.patch('/admin/:verificationId/approve', protect, admin, approveVerification);
router.patch('/admin/:verificationId/reject', protect, admin, rejectVerification);

module.exports = router;
