const express = require("express");
const router = express.Router();
const {
  createDonation,
  getAvailableDonations,
  getDonationById,
  getUserDonations,
  getDonationsByDeliveryOption,
  verifyDonation,
  rejectDonation,
  getPendingDonations,
  getAllDonations,
  assignDonation,
  getDonationStatistics,
  getDonationDashboardStats,
  completeDonation
} = require("../controllers/donationController");
const { protect, admin } = require('../middleware/authMiddleware');
const { requireDonor, requireRequester, requireApprovedStatus, requireDelivery } = require('../middleware/roleMiddleware');

// Create donation
router.post('/', protect, requireDonor, requireApprovedStatus, createDonation);

// Public donation routes
router.get("/", protect, getAvailableDonations);  // Remove requireApprovedStatus for volunteers
router.get("/my-donations", protect, requireDonor, requireApprovedStatus, getUserDonations);
router.get("/dashboard-stats", protect, requireDonor, requireApprovedStatus, getDonationDashboardStats);
router.get("/delivery-option/:deliveryOption", protect, getDonationsByDeliveryOption);

// Specific routes that must come BEFORE /:id route
router.get("/volunteer-deliveries", protect, (req, res, next) => {
  req.params.deliveryOption = 'Volunteer Delivery';
  getDonationsByDeliveryOption(req, res, next);
});

router.get("/paid-deliveries", protect, (req, res, next) => {
  req.params.deliveryOption = 'Paid Delivery';
  getDonationsByDeliveryOption(req, res, next);
});

// Debug route to check database state
router.get("/debug/delivery-options", protect, async (req, res) => {
  try {
    const allDonations = await Donation.find({}).select('title deliveryOption status verificationStatus');
    const paidDeliveries = await Donation.find({
      deliveryOption: 'Paid Delivery',
      status: 'available',
      verificationStatus: 'verified'
    }).select('title deliveryOption status verificationStatus');

    res.json({
      total: allDonations.length,
      paidDeliveries: paidDeliveries.length,
      allDonations: allDonations.map(d => ({
        title: d.title,
        deliveryOption: d.deliveryOption,
        status: d.status,
        verificationStatus: d.verificationStatus
      }))
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Debug route to check database state - COMPREHENSIVE TEST
router.get("/debug/comprehensive-check", protect, async (req, res) => {
  try {
    const Donation = require('../models/Donation');

    console.log('🔍 COMPREHENSIVE DATABASE CHECK STARTING...');

    // 1. Total donations
    const totalDonations = await Donation.countDocuments();
    console.log(`📊 Total donations in database: ${totalDonations}`);

    // 2. All delivery options
    const deliveryOptions = await Donation.distinct('deliveryOption');
    console.log(`📋 All delivery options: ${JSON.stringify(deliveryOptions)}`);

    // 3. Count by delivery option
    const counts = {};
    for (const option of deliveryOptions) {
      counts[option] = await Donation.countDocuments({ deliveryOption: option });
      console.log(`📦 "${option}": ${counts[option]} donations`);
    }

    // 4. Status breakdown
    const statuses = await Donation.distinct('status');
    console.log(`📋 All statuses: ${JSON.stringify(statuses)}`);

    const statusCounts = {};
    for (const status of statuses) {
      statusCounts[status] = await Donation.countDocuments({ status });
      console.log(`✅ Status "${status}": ${statusCounts[status]} donations`);
    }

    // 5. Specific checks for volunteer and paid deliveries
    const volunteerDeliveries = await Donation.find({
      deliveryOption: 'Volunteer Delivery',
      status: 'verified'
    }).select('title deliveryOption status assignedTo').limit(5);

    const paidDeliveries = await Donation.find({
      deliveryOption: 'Paid Delivery',
      status: 'verified'
    }).select('title deliveryOption status assignedTo').limit(5);

    console.log(`🎯 Volunteer deliveries (verified): ${volunteerDeliveries.length}`);
    console.log(`💰 Paid deliveries (verified): ${paidDeliveries.length}`);

    // 6. Sample data
    const sampleDonations = await Donation.find({})
      .select('title deliveryOption status assignedTo createdAt')
      .sort({ createdAt: -1 })
      .limit(10);

    console.log('📋 Sample donations (latest 10):');
    sampleDonations.forEach((donation, index) => {
      console.log(`  ${index + 1}. "${donation.title}" - ${donation.deliveryOption} - ${donation.status} - ${donation.assignedTo ? 'Assigned' : 'Available'}`);
    });

    res.json({
      success: true,
      summary: {
        totalDonations,
        deliveryOptions,
        counts,
        statuses,
        statusCounts,
        volunteerDeliveriesCount: volunteerDeliveries.length,
        paidDeliveriesCount: paidDeliveries.length
      },
      samples: {
        volunteerDeliveries: volunteerDeliveries.map(d => ({
          id: d._id,
          title: d.title,
          deliveryOption: d.deliveryOption,
          status: d.status,
          assigned: !!d.assignedTo
        })),
        paidDeliveries: paidDeliveries.map(d => ({
          id: d._id,
          title: d.title,
          deliveryOption: d.deliveryOption,
          status: d.status,
          assigned: !!d.assignedTo
        })),
        latestDonations: sampleDonations.map(d => ({
          id: d._id,
          title: d.title,
          deliveryOption: d.deliveryOption,
          status: d.status,
          assigned: !!d.assignedTo,
          createdAt: d.createdAt
        }))
      }
    });
  } catch (error) {
    console.error('❌ Error in comprehensive check:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Admin routes
router.get("/admin/stats", protect, admin, getDonationStatistics);
router.get("/admin/pending", protect, admin, getPendingDonations);
router.get("/admin/all", protect, admin, getAllDonations);

// Single donation (must be after specific routes)


// Donation assignment routes
router.patch("/:id/accept-volunteer", protect, assignDonation);
router.patch("/:id/accept-delivery", protect, assignDonation);

// Admin actions
router.patch('/:id/verify', protect, admin, verifyDonation);
router.patch('/:id/reject', protect, admin, rejectDonation);
router.patch('/:id/assign', protect, admin, assignDonation);

// Complete donation (donor action)
router.patch('/:donationId/complete', protect, requireDonor, requireApprovedStatus, completeDonation);

// Delete donation

module.exports = router;
