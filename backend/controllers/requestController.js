const Request = require("../models/Request");
const User = require("../models/User");
const { validateRequest } = require("../validators/requestValidator");

// @desc    Create a new food request
// @route   POST /api/requests
// @access  Private
const createRequest = async (req, res) => {
  try {
    const { error } = validateRequest(req.body);
    if (error) {
      return res.status(400).json({ message: error.details[0].message });
    }

    const {
      title,
      description,
      foodType,
      quantity,
      quantityUnit,
      neededBy,
      pickupAddress,
      latitude,
      longitude,
      notes,
      isUrgent,
      images,
    } = req.body;

    // Get requester information from authenticated user
    const requester = await User.findById(req.user.id);
    if (!requester) {
      return res.status(404).json({ message: "User not found" });
    }

    const request = new Request({
      requesterId: req.user.id,
      requesterName: requester.name,
      title,
      description,
      foodType,
      quantity,
      quantityUnit,
      neededBy,
      pickupAddress,
      latitude,
      longitude,
      notes,
      isUrgent: isUrgent || false,
      images: images || [],
      status: "pending",
    });

    const savedRequest = await request.save();

    res.status(201).json({
      message: "Request created successfully",
      request: savedRequest,
    });
  } catch (error) {
    console.error("Error creating request:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get all available requests with filters
// @route   GET /api/requests
// @access  Private
const getAvailableRequests = async (req, res) => {
  try {
    const {
      foodType,
      location,
      latitude,
      longitude,
      radius,
      isUrgent,
      status,
      page = 1,
      limit = 20,
    } = req.query;

    // Build filter object
    const filter = {};

    if (foodType) filter.foodType = { $regex: foodType, $options: "i" };
    if (isUrgent !== undefined) filter.isUrgent = isUrgent === "true";
    if (status) filter.status = status;

    // Location-based filtering
    if (latitude && longitude && radius) {
      const lat = parseFloat(latitude);
      const lng = parseFloat(longitude);
      const r = parseFloat(radius);

      filter.location = {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [lng, lat],
          },
          $maxDistance: r * 1000, // Convert km to meters
        },
      };
    }

    const skip = (page - 1) * limit;

    const requests = await Request.find(filter)
      .sort({ createdAt: -1, isUrgent: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate("requesterId", "name email phone");

    const total = await Request.countDocuments(filter);

    res.json({
      requests,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching requests:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get request by ID
// @route   GET /api/requests/:id
// @access  Private
const getRequestById = async (req, res) => {
  try {
    const request = await Request.findById(req.params.id).populate(
      "requesterId",
      "name email phone"
    );

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    res.json({ request });
  } catch (error) {
    console.error("Error fetching request:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get user's requests
// @route   GET /api/requests/my-requests
// @access  Private
const getUserRequests = async (req, res) => {
  try {
    const requests = await Request.find({ requesterId: req.user.id }).sort({
      createdAt: -1,
    });

    res.json({ requests });
  } catch (error) {
    console.error("Error fetching user requests:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Fulfill a request
// @route   PATCH /api/requests/:id/fulfill
// @access  Private
const fulfillRequest = async (req, res) => {
  try {
    const request = await Request.findById(req.params.id);

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    if (request.status !== "pending" && request.status !== "approved") {
      return res
        .status(400)
        .json({ message: "Request cannot be fulfilled with current status" });
    }

    if (request.requesterId.toString() === req.user.id) {
      return res
        .status(400)
        .json({ message: "Cannot fulfill your own request" });
    }

    // Check if request has passed the needed date
    if (new Date() > request.neededBy) {
      request.status = "expired";
      await request.save();
      return res
        .status(400)
        .json({ message: "Request has passed the needed date" });
    }

    request.status = "fulfilled";
    request.fulfilledBy = req.user.id;
    request.fulfilledAt = new Date();
    request.updatedAt = new Date();

    const updatedRequest = await request.save();

    res.json({
      message: "Request fulfilled successfully",
      request: updatedRequest,
    });
  } catch (error) {
    console.error("Error fulfilling request:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Update request status
// @route   PATCH /api/requests/:id/status
// @access  Private
const updateRequestStatus = async (req, res) => {
  try {
    const { status, reason } = req.body;
    const validStatuses = [
      "pending",
      "approved",
      "fulfilled",
      "cancelled",
      "expired",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const request = await Request.findById(req.params.id);

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    // Check if user is the requester or admin
    if (
      request.requesterId.toString() !== req.user.id &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({ message: "Not authorized" });
    }

    request.status = status;
    request.updatedAt = new Date();

    // Add reason for status change
    if (reason) {
      request.reason = reason;
    }

    // Reset fulfillment if status changes to pending or approved
    if (status === "pending" || status === "approved") {
      request.fulfilledBy = undefined;
      request.fulfilledAt = undefined;
    }

    const updatedRequest = await request.save();

    res.json({
      message: "Request status updated successfully",
      request: updatedRequest,
    });
  } catch (error) {
    console.error("Error updating request status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Cancel a request
// @route   PATCH /api/requests/:id/cancel
// @access  Private
const cancelRequest = async (req, res) => {
  try {
    const { reason } = req.body;

    if (!reason) {
      return res
        .status(400)
        .json({ message: "Reason is required for cancellation" });
    }

    const request = await Request.findById(req.params.id);

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    // Check if user is the requester or admin
    if (
      request.requesterId.toString() !== req.user.id &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // Check if request can be cancelled
    if (request.status === "fulfilled" || request.status === "cancelled") {
      return res
        .status(400)
        .json({ message: "Request cannot be cancelled with current status" });
    }

    request.status = "cancelled";
    request.reason = reason;
    request.updatedAt = new Date();

    const updatedRequest = await request.save();

    res.json({
      message: "Request cancelled successfully",
      request: updatedRequest,
    });
  } catch (error) {
    console.error("Error cancelling request:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Delete request
// @route   DELETE /api/requests/:id
// @access  Private
const deleteRequest = async (req, res) => {
  try {
    const request = await Request.findById(req.params.id);

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    // Check if user is the requester or admin
    if (
      request.requesterId.toString() !== req.user.id &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // Check if request can be deleted
    if (request.status === "fulfilled") {
      return res
        .status(400)
        .json({ message: "Cannot delete fulfilled request" });
    }

    await Request.findByIdAndDelete(req.params.id);

    res.json({ message: "Request deleted successfully" });
  } catch (error) {
    console.error("Error deleting request:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get requests by status
// @route   GET /api/requests/status/:status
// @access  Private
const getRequestsByStatus = async (req, res) => {
  try {
    const { status } = req.params;
    const validStatuses = [
      "pending",
      "approved",
      "fulfilled",
      "cancelled",
      "expired",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const requests = await Request.find({ status })
      .sort({ createdAt: -1 })
      .populate("requesterId", "name email phone");

    res.json({ requests });
  } catch (error) {
    console.error("Error fetching requests by status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get urgent requests
// @route   GET /api/requests/urgent
// @access  Private
const getUrgentRequests = async (req, res) => {
  try {
    const requests = await Request.find({
      isUrgent: true,
      status: { $in: ["pending", "approved"] },
      neededBy: { $gt: new Date() },
    })
      .sort({ neededBy: 1, createdAt: -1 })
      .populate("requesterId", "name email phone");

    res.json({ requests });
  } catch (error) {
    console.error("Error fetching urgent requests:", error);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
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
};
