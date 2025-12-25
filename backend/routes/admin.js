const express = require('express');
const router = express.Router();
const { protect, admin } = require('../middleware/authMiddleware');
const {
    getAllRequestsForAdmin,
    approveRequestByAdmin,
    rejectRequestByAdmin
} = require('../controllers/requestController');

// Admin request verification routes
router.get('/requests/pending', protect, admin, async (req, res) => {
    // Add verificationStatus=pending filter for admin panel
    req.query.verificationStatus = 'pending';
    return getAllRequestsForAdmin(req, res);
});

router.get('/requests/all', protect, admin, getAllRequestsForAdmin);
router.get('/requests/history', protect, admin, async (req, res) => {
    // Add verificationStatus filter for history (verified or rejected)
    req.query.verificationStatus = req.query.verificationStatus || 'verified,rejected';
    return getAllRequestsForAdmin(req, res);
});

router.patch('/requests/:id/approve', protect, admin, approveRequestByAdmin);
router.patch('/requests/:id/reject', protect, admin, rejectRequestByAdmin);

module.exports = router;
