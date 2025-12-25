const Request = require("../models/Request");
const User = require("../models/User");
const { logger } = require("../utils/logger");
const { logActivity } = require("../services/activityService");
const DeliveryNotificationService = require("./notificationController");
const {
  sendRequestVerifiedEmail,
  sendRequestRejectedEmail,
  sendRequestSubmittedEmail,
} = require("../services/emailService");
// Import centralized utilities
const {
  calculateDeliveryFee,
  calculateDistance,
  getCenterCoordinates,
} = require("../utils/deliveryUtils");

const OFFICE_ADDRESS = process.env.OFFICE_ADDRESS || "Central Karachi";
// Get center coordinates from utils
const center = getCenterCoordinates();
const OFFICE_LAT = parseFloat(
  process.env.OFFICE_LAT || center.latitude.toString()
);
const OFFICE_LNG = parseFloat(
  process.env.OFFICE_LNG || center.longitude.toString()
);

// Valid delivery options - consistent with frontend and donation controller
const validDeliveryOptions = [
  "Self delivery",
  "Volunteer Delivery",
  "Paid Delivery",
];

const isDelivery = (opt) =>
  ["Volunteer Delivery", "Paid Delivery", "Paid Delivery (Earn)"].includes(opt);

const num = (v) => (v === undefined || v === null ? undefined : parseFloat(v));
const parseDate = (v) => (v ? new Date(v) : undefined);

// calculateDistance function now imported from centralized utils

const createRequest = async (req, res) => {
  try {
    console.log("📝 CREATE REQUEST - Starting");
    console.log("📝 Request body:", JSON.stringify(req.body, null, 2));
    console.log("📝 User ID:", req.user?.id);

    if (!req.body || Object.keys(req.body).length === 0) {
      return res.status(400).json({
        message: "Request body is empty. Please provide request details.",
        required: [
          "title",
          "description",
          "foodType",
          "quantity",
          "quantityUnit",
          "neededBy",
          "pickupAddress",
          "latitude",
          "longitude",
        ],
      });
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
      deliveryOption = "Self delivery", // 👈 default is self
      // ✅ NEW: Payment and delivery fields
      paymentAmount,
      requestFee,
      paymentStatus,
      stripePaymentIntentId,
      distance,
      // Category-specific fields
      medicineName,
      prescriptionRequired,
      foodName,
      foodCategory,
      clothesGenderAge,
      clothesCondition,
      otherDescription,
    } = req.body;

    if (!description?.trim())
      return res.status(400).json({ message: "Description is required" });
    if (!title?.trim())
      return res.status(400).json({ message: "Title is required" });
    if (!foodType?.trim())
      return res.status(400).json({ message: "Food type is required" });
    if (!pickupAddress?.trim())
      return res.status(400).json({ message: "Pickup address is required" });

    console.log("📝 Finding requester user...");
    const requester = await User.findById(req.user.id);
    if (!requester) return res.status(404).json({ message: "User not found" });
    console.log("✅ Requester found:", requester.name, requester.email);

    const q = quantity ? parseInt(quantity, 10) || 1 : 1;
    const isUrgentBool = isUrgent === "true" || isUrgent === true;

    // Handle neededBy date
    let needed;
    if (neededBy) {
      needed = new Date(neededBy);
      if (Number.isNaN(needed.getTime())) {
        return res.status(400).json({ message: "Invalid neededBy date" });
      }
    } else {
      needed = new Date(Date.now() + 7 * 24 * 3600 * 1000);
    }

    // Handle location
    let finalAddress = pickupAddress;
    let finalLat = num(latitude) || OFFICE_LAT;
    let finalLng = num(longitude) || OFFICE_LNG;

    if (isNaN(finalLat) || isNaN(finalLng)) {
      console.log("⚠️ Invalid coordinates, using office defaults");
      finalLat = OFFICE_LAT;
      finalLng = OFFICE_LNG;
      finalAddress = finalAddress || OFFICE_ADDRESS;
    }

    // ✅ Distance & Fee calculation using payment middleware
    let distanceCalc = null;
    let deliveryFee = null;
    let serviceFee = 100; // Fixed service fee for all requests
    let totalAmount = serviceFee; // Start with service fee

    if (deliveryOption !== "Self delivery") {
      distanceCalc = calculateDistance(
        finalLat,
        finalLng,
        OFFICE_LAT,
        OFFICE_LNG
      );

      if (deliveryOption === "Paid Delivery") {
        deliveryFee = calculateDeliveryFee(distanceCalc);
        totalAmount = serviceFee + deliveryFee; // Service fee + delivery fee
      } else if (deliveryOption === "Volunteer Delivery") {
        deliveryFee = 0; // Free volunteer delivery
        totalAmount = serviceFee; // Only service fee
      }
    } else {
      // Self delivery - only service fee
      totalAmount = serviceFee;
    }

    console.log(
      `💰 Payment breakdown: Service Fee: ${serviceFee} PKR, Delivery Fee: ${
        deliveryFee || 0
      } PKR, Total: ${totalAmount} PKR`
    );

    console.log("📝 Creating request object...");
    const request = new Request({
      userId: requester._id,
      requestType: "food_request",
      title,
      description,
      priority: isUrgentBool ? "urgent" : "medium",
      status: "pending_verification",
      verificationStatus: "pending",
      metadata: {
        foodType: foodType || "Other",
        foodCategory:
          foodType === "Food"
            ? req.body.foodCategory || "Other Food Items"
            : undefined,
        foodName:
          foodType === "Food" ? req.body.foodName || title || "" : undefined,
        quantity: q,
        quantityUnit: quantityUnit || "items",
        neededBy: needed,
        pickupAddress: finalAddress,
        latitude: finalLat,
        longitude: finalLng,
        notes: notes || "",
        isUrgent: isUrgentBool,
        images: Array.isArray(images) ? images : [],
        deliveryOption, // 👈 store exactly what user selected
        distance: distanceCalc,
        serviceFee: serviceFee, // ✅ Save service fee (100 PKR)
        deliveryFee: deliveryFee, // ✅ Save delivery fee if paid
        totalAmount: totalAmount, // ✅ Save total amount
        paymentStatus,
        stripePaymentIntentId,
        medicineName,
        prescriptionRequired,
        clothesGenderAge,
        clothesCondition,
        otherDescription,
      },
      contactInfo: {
        email: requester.email,
        phone: requester.phone || "",
        address: finalAddress,
      },
    });

    console.log("📝 Saving request to database...");
    const savedRequest = await request.save();
    console.log("✅ Request saved successfully:", savedRequest._id);

    // Activity logging
    try {
      const Activity = require("../models/Activity");
      const activity = new Activity({
        userId: requester._id,
        type: "request_created",
        description: `Created request: ${savedRequest.title}`,
        metadata: {
          requestId: savedRequest._id,
          foodType: savedRequest.metadata.foodType,
          quantity: savedRequest.metadata.quantity,
          distance: savedRequest.metadata.distance,
          serviceFee: savedRequest.metadata.serviceFee,
          deliveryFee: savedRequest.metadata.deliveryFee,
          totalAmount: savedRequest.metadata.totalAmount,
        },
      });
      await activity.save();
    } catch (activityError) {
      console.error("❌ Failed to log activity:", activityError);
    }

    // Send request submitted email
    try {
      await sendRequestSubmittedEmail(requester.email, {
        requesterName: requester.name,
        requestTitle: savedRequest.title,
        requestId: savedRequest._id,
      });
    } catch (emailError) {
      console.error("Failed to send request submission email:", emailError);
    }

    console.log("✅ CREATE REQUEST - Completed successfully");
    return res.status(201).json({
      success: true,
      message: "Request created successfully",
      request: savedRequest,
    });
  } catch (error) {
    console.error("💥 CREATE REQUEST ERROR:", error);
    return res.status(500).json({
      success: false,
      message: "Something went wrong!",
      error: error.message,
    });
  }
};

const getAvailableRequests = async (req, res) => {
  try {
    const {
      foodType,
      latitude,
      longitude,
      radius,
      isUrgent,
      status,
      page = 1,
      limit = 20,
    } = req.query;

    const filter = {};

    if (foodType) filter.foodType = { $regex: foodType, $options: "i" };
    if (isUrgent !== undefined) filter.isUrgent = isUrgent === "true";
    if (status) filter.status = status;

    // Geo filtering (requires location field on docs)
    if (latitude && longitude && radius) {
      const lat = parseFloat(latitude);
      const lng = parseFloat(longitude);
      const rKm = parseFloat(radius);

      if (
        Number.isFinite(lat) &&
        Number.isFinite(lng) &&
        Number.isFinite(rKm)
      ) {
        filter.location = {
          $near: {
            $geometry: { type: "Point", coordinates: [lng, lat] },
            $maxDistance: rKm * 1000, // km -> m
          },
        };
      }
    }

    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const skip = (pageNum - 1) * limitNum;

    const requests = await Request.find(filter)
      .sort({ isUrgent: -1, createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .populate("userId", "name email phone");

    const total = await Request.countDocuments(filter);

    res.json({
      requests,
      pagination: {
        currentPage: pageNum,
        totalPages: Math.ceil(total / limitNum),
        totalItems: total,
        itemsPerPage: limitNum,
      },
    });
  } catch (error) {
    console.error("Error fetching requests:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const getRequestById = async (req, res) => {
  try {
    const request = await Request.findById(req.params.id).populate(
      "userId",
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

const getUserRequests = async (req, res) => {
  try {
    const requests = await Request.find({ userId: req.user.id }).sort({
      createdAt: -1,
    });

    res.json({ requests });
  } catch (error) {
    console.error("Error fetching user requests:", error);
    res.status(500).json({ message: "Server error" });
  }
};

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
      .populate("userId", "name email phone");

    res.json({ requests });
  } catch (error) {
    console.error("Error fetching requests by status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const getUrgentRequests = async (req, res) => {
  try {
    const requests = await Request.find({
      metadata: { isUrgent: true },
      status: { $in: ["pending", "approved"] },
      "metadata.neededBy": { $gt: new Date() },
    })
      .sort({ "metadata.neededBy": 1, createdAt: -1 })
      .populate("userId", "name email phone");

    res.json({ requests });
  } catch (error) {
    console.error("Error fetching urgent requests:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const getUserRecentRequests = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 10;

    // Validate user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Get user's recent requests
    const requests = await Request.find({ userId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .populate("userId", "name email")
      .populate("donor", "name email")
      .select(
        "title description requestType status urgencyLevel createdAt updatedAt"
      );

    console.log(
      `📊 Admin fetched user requests: ${requests.length} for user ${userId}`
    );

    res.json({
      success: true,
      requests,
      count: requests.length,
      userId,
    });
  } catch (error) {
    console.error("Get user recent requests error:", error.message);
    res.status(500).json({ message: "Server error fetching user requests" });
  }
};

const getRequestsByDeliveryOption = async (req, res) => {
  try {
    const { deliveryOption } = req.params;

    console.log("🔍 Getting requests by delivery option:", deliveryOption);

    // Handle special routes with consistent values
    let filterOption = deliveryOption;
    if (req.path.includes("/volunteer-deliveries")) {
      filterOption = "Volunteer Delivery";
    } else if (req.path.includes("/paid-deliveries")) {
      filterOption = "Paid Delivery";
    } else if (req.path.includes("/self-deliveries")) {
      filterOption = "Self delivery"; // Consistent with createRequest
    }

    // Validate the filter option
    if (!validDeliveryOptions.includes(filterOption)) {
      return res.status(400).json({
        success: false,
        message: `Invalid delivery option. Must be one of: ${validDeliveryOptions.join(
          ", "
        )}`,
      });
    }

    const requests = await Request.find({
      "metadata.deliveryOption": filterOption,
      verificationStatus: "verified",
      assignedTo: { $exists: false },
    })
      .sort({ createdAt: -1 })
      .populate("userId", "name email phone");

    console.log(
      `✅ Found ${requests.length} requests with deliveryOption: "${filterOption}"`
    );

    res.json({
      success: true,
      requests,
      filter: filterOption,
      count: requests.length,
    });
  } catch (error) {
    console.error("❌ Error fetching requests by delivery option:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
};

// Get request statistics
const getRequestStats = async (req, res) => {
  try {
    console.log("📊 Getting request statistics...");

    // Get all requests for the user
    const userRequests = await Request.find({ userId: req.user.id });

    // Simple stats - only 4 key metrics
    const totalRequests = userRequests.length;
    const verifiedRequests = userRequests.filter(
      (r) => r.verificationStatus === "verified"
    ).length;
    const pendingRequests = userRequests.filter(
      (r) => r.verificationStatus === "pending"
    ).length;
    const completedRequests = userRequests.filter(
      (r) => r.status === "completed" || r.status === "fulfilled"
    ).length;

    // Category breakdown for dashboard display
    const foodRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "food"
    ).length;
    const medicineRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "medicine"
    ).length;
    const clothesRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "clothes"
    ).length;
    const otherRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "other"
    ).length;

    const stats = {
      totalRequests,
      verifiedRequests,
      pendingRequests,
      completedRequests,
      foodRequests,
      medicineRequests,
      clothesRequests,
      otherRequests,
    };

    console.log("📊 Request stats calculated:", stats);

    res.json({
      success: true,
      stats,
    });
  } catch (error) {
    console.error("❌ Error getting request stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get request statistics",
      error: error.message,
    });
  }
};

// Get request dashboard statistics
const getRequestDashboardStats = async (req, res) => {
  try {
    console.log("📊 Getting request dashboard statistics...");

    // Get all requests for the user
    const userRequests = await Request.find({ userId: req.user.id });

    // Simple stats - only 4 key metrics (same as getRequestStats)
    const totalRequests = userRequests.length;
    const verifiedRequests = userRequests.filter(
      (r) => r.verificationStatus === "verified"
    ).length;
    const pendingRequests = userRequests.filter(
      (r) => r.verificationStatus === "pending"
    ).length;
    const completedRequests = userRequests.filter(
      (r) => r.status === "completed" || r.status === "fulfilled"
    ).length;

    // Category breakdown for dashboard display
    const foodRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "food"
    ).length;
    const medicineRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "medicine"
    ).length;
    const clothesRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "clothes"
    ).length;
    const otherRequests = userRequests.filter(
      (r) =>
        r.metadata &&
        r.metadata.foodType &&
        r.metadata.foodType.toLowerCase() === "other"
    ).length;

    // Service cost calculation - 100 PKR per request
    const SERVICE_COST_PER_REQUEST = 100;
    const totalServiceCost = totalRequests * SERVICE_COST_PER_REQUEST;
    const paidServiceCost = verifiedRequests * SERVICE_COST_PER_REQUEST;
    const pendingServiceCost = pendingRequests * SERVICE_COST_PER_REQUEST;

    // Recent activity
    const recentActivity = userRequests.slice(0, 5).map((request) => ({
      id: request._id,
      title: request.title,
      status: request.status,
      verificationStatus: request.verificationStatus,
      serviceCost: SERVICE_COST_PER_REQUEST,
      createdAt: request.createdAt,
      completedAt: request.status === "completed" ? request.updatedAt : null,
      foodType: request.metadata?.foodType || "Other",
      priority: request.priority,
    }));

    const stats = {
      totalRequests,
      verifiedRequests,
      pendingRequests,
      completedRequests,
      foodRequests,
      medicineRequests,
      clothesRequests,
      otherRequests,
      // Service cost information
      totalServiceCost,
      paidServiceCost,
      pendingServiceCost,
      serviceCostPerRequest: SERVICE_COST_PER_REQUEST,
      // Recent activity
      recentActivity,
      // Live update timestamp
      lastUpdated: new Date().toISOString(),
    };

    console.log("📊 Request dashboard stats calculated:", stats);

    res.json({
      success: true,
      stats,
    });
  } catch (error) {
    console.error("❌ Error getting request dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get request dashboard statistics",
      error: error.message,
    });
  }
};

const getAllRequestsForAdmin = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      verificationStatus,
      requestType,
      deliveryOption,
      search,
    } = req.query;

    // Build filter query
    const filter = {};

    if (status) filter.status = status;
    if (verificationStatus) filter.verificationStatus = verificationStatus;
    if (requestType)
      filter.requestType = { $regex: requestType, $options: "i" };

    // Filter by delivery option
    if (deliveryOption) {
      filter["metadata.deliveryOption"] = deliveryOption;
    }

    // Search functionality
    if (search) {
      filter.$or = [
        { title: { $regex: search, $options: "i" } },
        { description: { $regex: search, $options: "i" } },
        { "userId.name": { $regex: search, $options: "i" } },
      ];
    }

    const skip = (page - 1) * limit;
    const totalRequests = await Request.countDocuments(filter);

    const requests = await Request.find(filter)
      .populate("userId", "name email phone address")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    res.json({
      success: true,
      requests,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(totalRequests / limit),
        limit: parseInt(limit),
        totalItems: totalRequests,
      },
    });
  } catch (error) {
    console.error("❌ Error fetching requests for admin:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch requests",
      error: error.message,
    });
  }
};

const approveRequestByAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;
    const adminId = req.user.id;

    console.log(`🔍 Admin ${adminId} attempting to approve request ${id}`);
    console.log(`📝 Approval notes: ${notes || "None"}`);

    const request = await Request.findById(id).populate("userId", "name email");

    if (!request) {
      console.log(`❌ Request ${id} not found`);
      return res.status(404).json({
        success: false,
        message: "Request not found",
      });
    }

    console.log(`📋 Request found: ${request.title} by ${request.userId.name}`);
    console.log(
      `📋 Current status: ${request.status}, verification: ${request.verificationStatus}`
    );

    if (request.verificationStatus === "verified") {
      console.log(`⚠️ Request ${id} is already approved`);
      return res.status(400).json({
        success: false,
        message: "Request is already approved",
      });
    }

    // Update request status
    request.verificationStatus = "verified";
    request.status = "approved";
    request.verifiedBy = adminId;
    request.verificationDate = new Date();
    request.verificationNotes = notes || "";

    console.log(`💾 Saving request with new status: verified/approved`);
    await request.save();
    console.log(`✅ Request ${id} saved successfully`);

    // Send request approved email
    try {
      console.log(`📧 Sending approval email to ${request.userId.email}`);
      await sendRequestVerifiedEmail(request.userId.email, {
        requesterName: request.userId.name,
        requestTitle: request.title,
        verifiedAt: new Date(),
      });
      console.log(`✅ Approval email sent successfully`);
    } catch (emailError) {
      console.error("❌ Failed to send request approval email:", emailError);
    }
    // Notify delivery personnel and volunteers about new delivery opportunity
    try {
      if (
        request.metadata?.deliveryOption &&
        request.metadata.deliveryOption !== "Self delivery" &&
        request.metadata.deliveryOption !== "Self delivery"
      ) {
        console.log(
          "🚚 Notifying delivery personnel about approved request:",
          request._id
        );

        // Notify volunteers for volunteer delivery
        if (request.metadata.deliveryOption === "Volunteer Delivery") {
          await DeliveryNotificationService.notifyVolunteersNewDelivery(
            request
          );
        }

        // Notify paid delivery personnel for paid delivery options
        if (request.metadata.deliveryOption === "Paid Delivery") {
          await DeliveryNotificationService.notifyDeliveryPersonnelNewDelivery(
            request,
            "request"
          );
        }
      }
    } catch (notificationError) {
      console.error(
        "Failed to send delivery notifications:",
        notificationError
      );
    }

    console.log(`✅ Request approved by admin: ${id}`);

    res.json({
      success: true,
      message: "Request approved successfully",
      request,
    });
  } catch (error) {
    console.error("❌ Error approving request:", error);
    res.status(500).json({
      success: false,
      message: "Failed to approve request",
      error: error.message,
    });
  }
};

const rejectRequestByAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const adminId = req.user.id;

    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({
        success: false,
        message:
          "Rejection reason is required and must be at least 5 characters",
      });
    }

    const request = await Request.findById(id).populate("userId", "name email");

    if (!request) {
      return res.status(404).json({
        success: false,
        message: "Request not found",
      });
    }

    if (request.verificationStatus === "rejected") {
      return res.status(400).json({
        success: false,
        message: "Request is already rejected",
      });
    }

    // Update request status
    request.verificationStatus = "rejected";
    request.status = "rejected";
    request.verifiedBy = adminId;
    request.verificationDate = new Date();
    request.rejectionReason = reason.trim();

    await request.save();

    // Send request rejected email
    try {
      await sendRequestRejectedEmail(request.userId.email, {
        requesterName: request.userId.name,
        requestTitle: request.title,
        rejectionReason: reason.trim(),
      });
    } catch (emailError) {
      console.error("Failed to send request rejection email:", emailError);
    }

    console.log(`❌ Request rejected by admin: ${id} - Reason: ${reason}`);

    res.json({
      success: true,
      message: "Request rejected successfully",
      request,
      reason: reason.trim(),
    });
  } catch (error) {
    console.error("❌ Error rejecting request:", error);
    res.status(500).json({
      success: false,
      message: "Failed to reject request",
      error: error.message,
    });
  }
};

// Get service cost configuration
const getServiceCost = async (req, res) => {
  try {
    const SERVICE_COST_PER_REQUEST = 100; // PKR - Base fee for all requests

    res.json({
      success: true,
      serviceCost: SERVICE_COST_PER_REQUEST,
      currency: "PKR",
      description: "One-time service cost per request",
    });
  } catch (error) {
    console.error("Error getting service cost:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get service cost configuration",
    });
  }
};

module.exports = {
  createRequest,
  getAvailableRequests,
  getRequestById,
  getUserRequests,

  getRequestsByStatus,
  getUrgentRequests,
  getUserRecentRequests,
  getRequestsByDeliveryOption,
  getRequestStats,
  getRequestDashboardStats,
  getAllRequestsForAdmin,
  approveRequestByAdmin,
  rejectRequestByAdmin,
  getServiceCost,
};
