const express = require("express");
const router = express.Router();

const {
  createRequest,
  getAvailableRequests,
  getRequestById,
  getUserRequests,
  getRequestsByDeliveryOption,
  getRequestDashboardStats,
  getAllRequestsForAdmin,
  approveRequestByAdmin,
  rejectRequestByAdmin,
  getServiceCost,
} = require("../controllers/requestController");

const { protect, admin } = require("../middleware/authMiddleware");
const {
  requireRequester,
  requireDonor,
  requireApprovedStatus,
  requireApprovedRole,
} = require("../middleware/roleMiddleware");
const { requireVerification } = require("../middleware/verificationMiddleware");

// Create request (REQUESTERS ONLY - requires email verification and payment)
router.post("/", protect, requireRequester, createRequest);

// Public request routes
router.get("/", protect, getAvailableRequests);
router.get(
  "/my-requests",
  protect,
  requireRequester,
  requireApprovedStatus,
  getUserRequests
);
router.get(
  "/dashboard-stats",
  protect,
  requireRequester,
  requireApprovedStatus,
  getRequestDashboardStats
);
router.get(
  "/delivery-option/:deliveryOption",
  protect,
  getRequestsByDeliveryOption
);
router.get("/service-cost", protect, getServiceCost);

// Volunteer and delivery assignment routes for requests
router.get("/volunteer-deliveries", protect, (req, res, next) => {
  req.params.deliveryOption = "Volunteer Delivery";
  getRequestsByDeliveryOption(req, res, next);
});

router.get("/paid-deliveries", protect, (req, res, next) => {
  req.params.deliveryOption = "Paid Delivery";
  getRequestsByDeliveryOption(req, res, next);
});

// Debug route to check database state
router.get("/debug/delivery-options", protect, async (req, res) => {
  try {
    const Request = require("../models/Request");

    // Get all unique delivery options from metadata
    const allRequests = await Request.find(
      {},
      { "metadata.deliveryOption": 1 }
    );
    const deliveryOptions = [
      ...new Set(
        allRequests.map((r) => r.metadata?.deliveryOption).filter(Boolean)
      ),
    ];

    // Get count of requests by delivery option
    const counts = {};
    for (const option of deliveryOptions) {
      counts[option] = await Request.countDocuments({
        "metadata.deliveryOption": option,
      });
    }

    // Get count of verified requests by delivery option
    const verifiedCounts = {};
    for (const option of deliveryOptions) {
      verifiedCounts[option] = await Request.countDocuments({
        "metadata.deliveryOption": option,
        verificationStatus: "verified",
      });
    }

    // Get total counts
    const totalRequests = await Request.countDocuments();
    const verifiedRequests = await Request.countDocuments({
      verificationStatus: "verified",
    });

    res.json({
      success: true,
      deliveryOptions,
      counts,
      verifiedCounts,
      totalRequests,
      verifiedRequests,
      message: "Database state for request delivery options",
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Single request (approved users can view)
router.get("/:id", protect, requireApprovedStatus, getRequestById);

// Admin routes for request verification
router.get("/admin/all", protect, admin, getAllRequestsForAdmin);
router.patch("/admin/:id/approve", protect, admin, approveRequestByAdmin);
router.patch("/admin/:id/reject", protect, admin, rejectRequestByAdmin);

module.exports = router;
