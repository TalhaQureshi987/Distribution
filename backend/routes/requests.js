const express = require("express");
const router = express.Router();

const {
  createRequest,
  getAvailableRequests,
  getRequestById,
  getUserRequests,
  fulfillRequest,
  updateRequestStatus,
  cancelRequest,
  deleteRequest,
  getRequestsByStatus,
  getUrgentRequests,
} = require("../controllers/requestController");

const { protect } = require("../middleware/authMiddleware");

// Create request
router.post("/", protect, createRequest);

// List requests
router.get("/", protect, getAvailableRequests);

// My requests
router.get("/my-requests", protect, getUserRequests);

// Urgent requests
router.get("/urgent", protect, getUrgentRequests);

// Requests by status
router.get("/status/:status", protect, getRequestsByStatus);

// Single request (must be last to avoid conflicts)
router.get("/:id", protect, getRequestById);

// Fulfill
router.patch("/:id/fulfill", protect, fulfillRequest);

// Update status
router.patch("/:id/status", protect, updateRequestStatus);

// Cancel
router.patch("/:id/cancel", protect, cancelRequest);

// Delete
router.delete("/:id", protect, deleteRequest);

module.exports = router;
