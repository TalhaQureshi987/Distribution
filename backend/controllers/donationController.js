const Donation = require("../models/Donation");
const User = require("../models/User");
const Activity = require("../models/Activity");
const DeliveryCommission = require("../models/DeliveryCommission");
const Payment = require("../models/Payment"); // Import Payment model
const { getIO } = require("../logic/socket"); // Import getIO function
const {
  sendDonationVerifiedEmail,
  sendDonationRejectedEmail,
  sendDonationSubmittedEmail,
  sendNewDonationNotificationEmail,
} = require("../services/emailService");
const DeliveryNotificationService = require("./notificationController");
const { logger } = require("../utils/logger");

// Import centralized utilities at the top
const {
  calculateDeliveryFee,
  calculateDistance,
  getCenterCoordinates,
} = require("../utils/deliveryUtils");

const createDonation = async (req, res) => {
  try {
    console.log("📝 CREATE DONATION - Starting");
    console.log("📝 Request body:", JSON.stringify(req.body, null, 2));
    console.log("📝 User ID:", req.user?.id);

    if (!req.body || Object.keys(req.body).length === 0) {
      console.log("❌ Empty request body");
      return res.status(400).json({
        message: "Request body is empty. Please provide donation details.",
        required: [
          "title",
          "description",
          "foodType",
          "quantity",
          "quantityUnit",
          "expiryDate",
          "pickupAddress",
          "latitude",
          "longitude",
        ],
      });
    }

    if (!req.body.description || req.body.description.trim().length === 0) {
      console.log("❌ Missing description");
      return res.status(400).json({ message: "Description is required" });
    }

    if (!req.body.title || req.body.title.trim().length === 0) {
      console.log("❌ Missing title");
      return res.status(400).json({ message: "Title is required" });
    }

    if (!req.body.foodType || req.body.foodType.trim().length === 0) {
      console.log("❌ Missing food type");
      return res.status(400).json({ message: "Food type is required" });
    }

    if (!req.body.pickupAddress || req.body.pickupAddress.trim().length === 0) {
      console.log("❌ Missing pickup address");
      return res.status(400).json({ message: "Pickup address is required" });
    }

    console.log("📝 Finding donor user...");
    const donor = await User.findById(req.user.id);
    if (!donor) {
      console.log("❌ User not found:", req.user.id);
      return res.status(404).json({ message: "User not found" });
    }
    console.log("✅ Donor found:", donor.name, donor.email);

    // Handle file uploads and save images
    let savedImages = [];
    if (req.files && req.files.length > 0) {
      console.log("📸 Processing uploaded files:", req.files.length);

      const fs = require("fs").promises;
      const path = require("path");

      // Ensure uploads directory exists
      const uploadsDir = path.join(__dirname, "..", "uploads", "donations");
      try {
        await fs.mkdir(uploadsDir, { recursive: true });
      } catch (err) {
        console.log("📁 Directory already exists or created:", uploadsDir);
      }

      for (const file of req.files) {
        try {
          const filename = `${Date.now()}-${Math.random()
            .toString(36)
            .substring(7)}.${file.originalname.split(".").pop()}`;
          const filepath = path.join(uploadsDir, filename);

          await fs.writeFile(filepath, file.buffer);
          const imageUrl = `/uploads/donations/${filename}`;
          savedImages.push(imageUrl);

          console.log("✅ Image saved:", imageUrl);
        } catch (error) {
          console.error("❌ Error saving image:", error);
        }
      }
    }

    // Use saved images or provided image URLs
    const imageUrls =
      savedImages.length > 0
        ? savedImages
        : Array.isArray(req.body.images)
        ? req.body.images
        : [];
    console.log("📸 Final image URLs:", imageUrls);

    const quantity = req.body.quantity
      ? parseInt(req.body.quantity, 10) || 1
      : 1;
    const isUrgent = req.body.isUrgent === "true" || req.body.isUrgent === true;
    // Get delivery option from request - don't override user's choice
    // Get delivery option from request
    const deliveryOption = req.body.deliveryOption;
    console.log("🚚 DELIVERY OPTION received:", deliveryOption);

    // Validate delivery option - use consistent values
    const validOptions = [
      "Self delivery",
      "Volunteer Delivery",
      "Paid Delivery",
    ];
    if (!deliveryOption || !validOptions.includes(deliveryOption)) {
      return res.status(400).json({
        message: `Invalid delivery option. Must be one of: ${validOptions.join(
          ", "
        )}`,
      });
    }

    // Calculate distance and delivery fee for non-self-pickup options
    let deliveryDistance = 0;
    let deliveryFee = 0;

    if (deliveryOption !== "Self delivery") {
      try {
        // Get center coordinates from utils
        const center = getCenterCoordinates();
        const careConnectLat = center.latitude;
        const careConnectLon = center.longitude;
        const donorLat = req.body.latitude
          ? parseFloat(req.body.latitude)
          : 0.0;
        const donorLon = req.body.longitude
          ? parseFloat(req.body.longitude)
          : 0.0;

        if (donorLat && donorLon) {
          deliveryDistance = calculateDistance(
            donorLat,
            donorLon,
            careConnectLat,
            careConnectLon
          );
          console.log(
            `📍 Delivery distance calculated: ${deliveryDistance.toFixed(2)} km`
          );

          if (deliveryOption === "Paid Delivery") {
            deliveryFee = calculateDeliveryFee(deliveryDistance);
            console.log(`💰 Delivery fee calculated: ${deliveryFee} PKR`);
          }
        }
      } catch (error) {
        console.error("❌ Error calculating distance:", error);
      }
    }

    console.log("📝 Creating donation object...");
    const donation = new Donation({
      donorId: donor._id,
      donorName: donor.name,
      title: req.body.title || "",
      description: req.body.description,
      foodType: req.body.foodType || "Other",
      foodCategory:
        req.body.foodType === "Food"
          ? req.body.foodCategory || "Other Food Items"
          : undefined,
      foodName:
        req.body.foodType === "Food"
          ? req.body.foodName || req.body.title || ""
          : undefined,
      quantity,
      quantityUnit: req.body.quantityUnit || "items",
      expiryDate: req.body.expiryDate
        ? new Date(req.body.expiryDate)
        : new Date(Date.now() + 7 * 24 * 3600 * 1000),
      pickupAddress: req.body.pickupAddress,
      latitude: req.body.latitude ? parseFloat(req.body.latitude) : 0.0,
      longitude: req.body.longitude ? parseFloat(req.body.longitude) : 0.0,
      notes: req.body.notes || "",
      isUrgent,
      images: imageUrls,
      deliveryOption: deliveryOption,
      deliveryDistance:
        deliveryOption !== "Self delivery" ? deliveryDistance : undefined,
      paymentAmount:
        deliveryOption === "Paid Delivery" ? deliveryFee : undefined,
      status: "available",
      verificationStatus: "pending",
    });

    console.log("📝 Saving donation to database...");
    const saved = await donation.save();
    console.log("✅ Donation saved successfully:", saved._id);

    // Send verification email to donor
    try {
      console.log("📧 Sending verification email to donor...");
      await sendDonationSubmittedEmail(donor.email, {
        donorName: donor.name,
        donationTitle: saved.title,
        donationId: saved._id,
        submissionDate: saved.createdAt,
      });
      console.log("✅ Verification email sent to donor");
    } catch (emailError) {
      console.error("❌ Failed to send verification email:", emailError);
    }

    // Notify admins about new donation
    try {
      console.log("📧 Notifying admins about new donation...");
      const admins = await User.find({ role: "admin" });
      console.log(`📧 Found ${admins.length} admins to notify`);

      for (const admin of admins) {
        try {
          await sendNewDonationNotificationEmail(admin.email, {
            adminName: admin.name,
            donorName: donor.name,
            donationTitle: saved.title,
            donationId: saved._id,
            submissionDate: saved.createdAt,
          });
          console.log(`✅ Notification sent to admin: ${admin.email}`);
        } catch (adminEmailError) {
          console.error(
            `❌ Failed to send notification to admin ${admin.email}:`,
            adminEmailError
          );
        }
      }
    } catch (adminNotifyError) {
      console.error("❌ Failed to notify admins:", adminNotifyError);
    }

    // Log activity
    try {
      console.log("📝 Logging donation activity...");
      const activity = new Activity({
        userId: donor._id,
        type: "donation_created",
        description: `Created donation: ${saved.title}`,
        metadata: {
          donationId: saved._id,
          foodType: saved.foodType,
          quantity: saved.quantity,
        },
      });
      await activity.save();
      console.log("✅ Activity logged");
    } catch (activityError) {
      console.error("❌ Failed to log activity:", activityError);
    }

    console.log("✅ CREATE DONATION - Completed successfully");
    return res.status(201).json({
      message: "Donation created successfully",
      donation: saved,
    });
  } catch (err) {
    console.error("💥 CREATE DONATION ERROR:", err);
    console.error("💥 Error stack:", err.stack);
    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({ message: "File too large" });
    }
    return res
      .status(500)
      .json({ message: "Something went wrong!", error: err.message });
  }
};

// @desc    Get pending donations for admin verification
// @route   GET /api/donations/admin/pending
// @access  Private (Admin only)
const getPendingDonations = async (req, res) => {
  try {
    const { deliveryOption } = req.query;

    // Build filter query
    const filter = {
      verificationStatus: "pending",
    };

    // Filter by delivery option if provided
    if (deliveryOption) {
      filter["metadata.deliveryOption"] = deliveryOption;
    }

    const donations = await Donation.find(filter)
      .sort({ createdAt: -1 })
      .populate("donorId", "name email phone")
      .select(
        "title description foodType quantity verificationStatus createdAt donorId pickupAddress images deliveryOption paymentAmount deliveryDistance metadata"
      );

    res.json({
      donations,
      count: donations.length,
    });
  } catch (error) {
    console.error("Error fetching pending donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Admin verify donation
// @route   PATCH /api/donations/:id/verify
// @access  Private (Admin only)
const verifyDonation = async (req, res) => {
  try {
    console.log("🔍 VERIFY DONATION - Starting verification process");
    console.log("📋 Request params:", req.params);
    console.log("📋 Request body:", req.body);
    console.log("👤 Admin user:", req.user?.email);

    const { id } = req.params;
    const { notes } = req.body;

    console.log("🔍 Looking for donation with ID:", id);
    const donation = await Donation.findById(id).populate(
      "donorId",
      "name email"
    );

    if (!donation) {
      console.log("❌ Donation not found with ID:", id);
      return res.status(404).json({ message: "Donation not found" });
    }

    console.log("✅ Found donation:", {
      id: donation._id,
      title: donation.title,
      currentStatus: donation.verificationStatus,
      donorEmail: donation.donorId?.email,
      donorName: donation.donorId?.name,
    });

    if (donation.verificationStatus === "verified") {
      console.log("⚠️ Donation already verified");
      return res.status(400).json({ message: "Donation already verified" });
    }

    console.log("🔄 Updating donation verification status...");
    donation.verificationStatus = "verified";
    donation.verifiedBy = req.user._id;
    donation.verifiedAt = new Date();
    donation.verificationNotes = notes || "";

    await donation.save();
    console.log("✅ Donation saved successfully");

    // Send email notification to donor FIRST
    console.log("📧 Attempting to send verification email...");
    try {
      await sendDonationVerifiedEmail(donation.donorId.email, {
        donorName: donation.donorId.name,
        donationTitle: donation.title,
        verifiedAt: donation.verifiedAt,
      });
      console.log("✅ Donation verification email sent successfully");
    } catch (emailError) {
      console.error("❌ Failed to send verification email:", emailError);
    }

    // 🚚 Notify delivery personnel and volunteers about new delivery opportunity
    try {
      if (
        donation.deliveryOption &&
        donation.deliveryOption !== "Self delivery"
      ) {
        console.log(
          "🚚 Notifying delivery personnel about verified donation:",
          donation._id
        );

        // Notify volunteers for volunteer delivery
        if (donation.deliveryOption === "Volunteer Delivery") {
          await DeliveryNotificationService.notifyVolunteersNewDelivery(
            donation
          );
        }

        // Notify paid delivery personnel for paid delivery options
        if (donation.deliveryOption === "Paid Delivery") {
          await DeliveryNotificationService.notifyDeliveryPersonnelNewDelivery(
            donation,
            "donation"
          );
        }
      }
    } catch (notificationError) {
      console.error(
        "❌ Failed to send delivery notifications:",
        notificationError
      );
    }

    // Send real-time notification with SINGLE consolidated event
    console.log("🔔 Sending donation verification notification...");
    try {
      const { getIO } = require("../logic/socket");
      const io = getIO();

      if (io) {
        const roomName = `user_${donation.donorId._id}`;
        console.log(
          `🎯 SOCKET: Emitting donation_verified to room: ${roomName}`
        );

        const socketsInRoom = await io.in(roomName).fetchSockets();
        console.log(
          `🎯 SOCKET: Sockets in room ${roomName}: ${socketsInRoom.length}`
        );

        const notificationData = {
          type: "donation_verified",
          title: "🎉 Donation Approved!",
          message: `Your donation "${donation.title}" has been verified and is now live on the platform!`,
          user: {
            _id: donation.donorId._id,
            name: donation.donorId.name,
            email: donation.donorId.email,
          },
          donation: {
            _id: donation._id,
            title: donation.title,
            verificationStatus: "verified",
            verifiedAt: donation.verifiedAt,
          },
          refreshDashboard: true,
          showToast: true,
          immediate: true,
          timestamp: new Date().toISOString(),
        };

        console.log(
          `🎯 SOCKET: Notification data:`,
          JSON.stringify(notificationData, null, 2)
        );

        const io = getIO();
        io.to(roomName).emit("donation_verification_update", notificationData);

        io.sockets.sockets.forEach((socket) => {
          if (socket.userId === donation.donorId._id.toString()) {
            console.log(
              `🎯 SOCKET: Direct emit to socket ${socket.id} for user ${socket.userId}`
            );
            socket.emit("donation_verification_update", notificationData);
          }
        });

        console.log(
          `✅ Donation verification notification sent to user_${donation.donorId._id}`
        );
        console.log(`📡 Event sent: donation_verification_update`);
      } else {
        console.log("❌ Socket.IO instance not available");
      }
    } catch (socketError) {
      console.error("❌ Failed to send real-time notification:", socketError);
    }

    // Create activity log
    try {
      const activity = new Activity({
        userId: req.user._id,
        type: "donation_verified",
        description: `Admin verified donation: ${donation.title}`,
        metadata: {
          donationId: donation._id,
          donorId: donation.donorId._id,
          notes: notes,
        },
      });
      await activity.save();
      console.log("✅ Activity log created");
    } catch (activityError) {
      console.error("❌ Failed to create activity log:", activityError);
    }

    console.log("🎉 Verification process completed successfully");
    res.json({
      message: "Donation verified successfully",
      donation: {
        id: donation._id,
        title: donation.title,
        verificationStatus: donation.verificationStatus,
        verifiedAt: donation.verifiedAt,
      },
    });
  } catch (error) {
    console.error("💥 CRITICAL ERROR in verifyDonation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Admin reject donation
// @route   PATCH /api/donations/:id/reject
// @access  Private (Admin only)
const rejectDonation = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    if (!reason) {
      return res.status(400).json({ message: "Rejection reason is required" });
    }

    const donation = await Donation.findById(id).populate(
      "donorId",
      "name email"
    );
    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    if (donation.verificationStatus === "rejected") {
      return res.status(400).json({ message: "Donation already rejected" });
    }

    // Update donation verification status
    donation.verificationStatus = "rejected";
    donation.verifiedBy = req.user._id;
    donation.verifiedAt = new Date();
    donation.verificationNotes = reason;

    await donation.save();

    // Send email notification to donor
    try {
      await sendDonationRejectedEmail(donation.donorId.email, {
        donorName: donation.donorId.name,
        donationTitle: donation.title,
        rejectionReason: reason,
        rejectedAt: donation.verifiedAt,
      });
      console.log("✅ Rejection email sent successfully");
    } catch (emailError) {
      console.error("❌ Failed to send rejection email:", emailError);
    }

    // Send real-time notification via Socket.IO
    try {
      const io = getIO();
      io.emit(`user_${donation.donorId._id}`, "donation_rejected", {
        type: "donation_rejected",
        donationId: donation._id,
        title: donation.title,
        reason: reason,
        message: "Your donation has been rejected by admin",
      });
      console.log("✅ Real-time rejection notification sent successfully");
    } catch (socketError) {
      console.error(
        "❌ Failed to send real-time rejection notification:",
        socketError
      );
    }

    // Create activity log
    const activity = new Activity({
      userId: req.user._id,
      type: "donation_rejected",
      description: `Admin rejected donation: ${donation.title}`,
      metadata: {
        donationId: donation._id,
        donorId: donation.donorId._id,
        reason: reason,
      },
    });
    await activity.save();

    res.json({
      message: "Donation rejected successfully",
      donation: {
        id: donation._id,
        title: donation.title,
        verificationStatus: donation.verificationStatus,
        rejectionReason: reason,
      },
    });
  } catch (error) {
    console.error("Error rejecting donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get all donations for admin (history)
// @route   GET /api/donations/admin/all
// @access  Private (Admin only)
const getAllDonations = async (req, res) => {
  try {
    const { page = 1, limit = 20, status, foodType } = req.query;

    const filter = {};
    if (status && status !== "all") {
      filter.verificationStatus = status;
    }
    if (foodType && foodType !== "all") {
      filter.foodType = foodType;
    }

    const skip = (page - 1) * limit;

    const donations = await Donation.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate("donorId", "name email phone")
      .select(
        "title description foodType foodCategory foodName quantity verificationStatus createdAt donorId pickupAddress images deliveryOption paymentAmount deliveryDistance"
      );

    const total = await Donation.countDocuments(filter);

    res.json({
      donations,
      count: donations.length,
      total,
      page: parseInt(page),
      totalPages: Math.ceil(total / limit),
    });
  } catch (error) {
    console.error("Error fetching all donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get available donations with filters
// @route   GET /api/donations
// @access  Private
const getAvailableDonations = async (req, res) => {
  try {
    const {
      foodType,
      location,
      latitude,
      longitude,
      radius,
      isUrgent,
      page = 1,
      limit = 20,
    } = req.query;

    const filter = {
      status: "available",
      verificationStatus: "verified", // Only show verified donations
    };

    if (foodType) filter.foodType = { $regex: foodType, $options: "i" };
    if (isUrgent !== undefined) filter.isUrgent = isUrgent === "true";

    const skip = (page - 1) * limit;

    const donations = await Donation.find(filter)
      .sort({ createdAt: -1, isUrgent: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate("donorId", "name email phone");

    const total = await Donation.countDocuments(filter);

    res.json({
      donations,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get donation by ID
// @route   GET /api/donations/:id
// @access  Private
const getDonationById = async (req, res) => {
  try {
    const donation = await Donation.findById(req.params.id).populate(
      "donorId",
      "name email phone"
    );

    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    res.json({ donation });
  } catch (error) {
    console.error("Error fetching donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get user's donations
// @route   GET /api/donations/my-donations
// @access  Private
const getUserDonations = async (req, res) => {
  try {
    console.log("📊 GET USER DONATIONS - Starting");
    console.log("📊 User ID:", req.user.id);
    console.log("📊 User email:", req.user.email);

    const donations = await Donation.find({ donorId: req.user.id }).sort({
      createdAt: -1,
    });

    console.log("📊 Found donations count:", donations.length);
    console.log(
      "📊 Donations:",
      donations.map((d) => ({
        id: d._id,
        title: d.title,
        status: d.status,
        verificationStatus: d.verificationStatus,
      }))
    );

    res.json({ donations });
  } catch (error) {
    console.error("💥 Error fetching user donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get user's donation statistics for dashboard
// @route   GET /api/donations/stats
// @access  Private
const getDonationStats = async (req, res) => {
  try {
    console.log("📊 GET DONATION STATS - Starting");
    console.log("📊 User ID:", req.user.id);
    console.log("📊 User email:", req.user.email);

    const userId = req.user.id;

    const donations = await Donation.find({ donorId: userId });

    console.log("📊 Found donations count:", donations.length);

    // Simple stats - only 4 key metrics
    const totalDonations = donations.length;
    const verifiedDonations = donations.filter(
      (d) => d.verificationStatus === "verified"
    ).length;
    const pendingDonations = donations.filter(
      (d) => d.verificationStatus === "pending"
    ).length;
    const completedDonations = donations.filter(
      (d) => d.status === "completed"
    ).length;

    res.json({
      success: true,
      stats: {
        totalDonations,
        verifiedDonations,
        pendingDonations,
        completedDonations,
      },
    });
  } catch (error) {
    console.error("Get donation stats error:", error);
    res
      .status(500)
      .json({ message: "Server error fetching donation statistics" });
  }
};

const getDonationDashboardStats = async (req, res) => {
  try {
    console.log("📊 Getting donation dashboard statistics...");

    // Get all donations for the user
    const userDonations = await Donation.find({ donorId: req.user.id });

    console.log("📊 Found donations count:", userDonations.length);
    console.log(
      "📊 Donations:",
      userDonations.map((d) => ({
        id: d._id,
        title: d.title,
        foodType: d.foodType,
        status: d.status,
        verificationStatus: d.verificationStatus,
      }))
    );

    // Status breakdown
    const totalDonations = userDonations.length;
    const pendingDonations = userDonations.filter(
      (d) => d.status === "pending"
    ).length;
    const verifiedDonations = userDonations.filter(
      (d) => d.verificationStatus === "verified"
    ).length;
    const pendingVerificationDonations = userDonations.filter(
      (d) => d.verificationStatus === "pending"
    ).length;

    // Food type breakdown with detailed stats - Fixed case sensitivity
    console.log(
      "📊 DEBUG: All donation foodTypes:",
      userDonations.map((d) => ({
        id: d._id,
        title: d.title,
        foodType: d.foodType,
        rawFoodType: JSON.stringify(d.foodType),
      }))
    );

    const foodTypeStats = {};

    // Count actual foodType values first
    const actualFoodTypes = {};
    userDonations.forEach((d) => {
      if (d.foodType) {
        const normalizedType = d.foodType.toLowerCase().trim();
        actualFoodTypes[normalizedType] =
          (actualFoodTypes[normalizedType] || 0) + 1;
      }
    });

    console.log("📊 DEBUG: Actual foodType counts:", actualFoodTypes);

    // Initialize stats for expected types
    const expectedTypes = ["food", "clothes", "medicine", "other"];
    expectedTypes.forEach((type) => {
      foodTypeStats[type] = {
        total: 0,
        pending: 0,
        verified: 0,
        completed: 0,
        recent: [],
      };
    });

    // Map actual types to expected types and count
    userDonations.forEach((d) => {
      if (d.foodType) {
        const normalizedType = d.foodType.toLowerCase().trim();
        let mappedType = normalizedType;

        // Handle potential variations
        if (normalizedType.includes("food")) mappedType = "food";
        else if (normalizedType.includes("cloth")) mappedType = "clothes";
        else if (
          normalizedType.includes("medicine") ||
          normalizedType.includes("medical")
        )
          mappedType = "medicine";
        else if (!expectedTypes.includes(normalizedType)) mappedType = "other";

        if (foodTypeStats[mappedType]) {
          foodTypeStats[mappedType].total++;
          if (d.status === "pending") foodTypeStats[mappedType].pending++;
          if (d.verificationStatus === "verified")
            foodTypeStats[mappedType].verified++;
          if (d.status === "completed") foodTypeStats[mappedType].completed++;
        }
      }
    });

    // Add recent items for each type
    expectedTypes.forEach((type) => {
      const typeRecentDonations = userDonations
        .filter((d) => {
          if (!d.foodType) return false;
          const normalizedType = d.foodType.toLowerCase().trim();
          let mappedType = normalizedType;

          if (normalizedType.includes("food")) mappedType = "food";
          else if (normalizedType.includes("cloth")) mappedType = "clothes";
          else if (
            normalizedType.includes("medicine") ||
            normalizedType.includes("medical")
          )
            mappedType = "medicine";
          else if (!expectedTypes.includes(normalizedType))
            mappedType = "other";

          return mappedType === type;
        })
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 3)
        .map((d) => ({
          id: d._id,
          title: d.title,
          status: d.status,
          verificationStatus: d.verificationStatus,
          createdAt: d.createdAt,
          quantity: d.quantity,
        }));

      foodTypeStats[type].recent = typeRecentDonations;
      console.log(`📊 DEBUG: ${type} final stats:`, foodTypeStats[type]);
    });

    // Delivery option breakdown
    const deliveryOptions = [
      "Self delivery",
      "Volunteer Delivery",
      "Paid Delivery",
    ];
    const deliveryStats = {};

    deliveryOptions.forEach((option) => {
      const optionDonations = userDonations.filter(
        (d) => d.deliveryOption === option
      );
      deliveryStats[option.toLowerCase().replace(" ", "_")] = {
        total: optionDonations.length,
        pending: optionDonations.filter((d) => d.status === "pending").length,
        completed: optionDonations.filter((d) => d.status === "completed")
          .length,
      };
    });

    // Recent activity with more details
    const recentActivity = userDonations
      .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt))
      .slice(0, 5)
      .map((d) => ({
        id: d._id,
        title: d.title,
        foodType: d.foodType,
        status: d.status,
        verificationStatus: d.verificationStatus,
        deliveryOption: d.deliveryOption,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
        quantity: d.quantity,
      }));

    // Monthly donation trends
    const monthlyStats = {};
    const last6Months = [];
    for (let i = 5; i >= 0; i--) {
      const date = new Date();
      date.setMonth(date.getMonth() - i);
      const monthKey = date.toISOString().slice(0, 7); // YYYY-MM format
      last6Months.push(monthKey);
      monthlyStats[monthKey] = 0;
    }

    userDonations.forEach((d) => {
      const monthKey = d.createdAt.toISOString().slice(0, 7);
      if (monthlyStats.hasOwnProperty(monthKey)) {
        monthlyStats[monthKey]++;
      }
    });

    const stats = {
      overview: {
        totalDonations,
        pendingDonations,
        verifiedDonations,
        pendingVerificationDonations,
        completedDonations: userDonations.filter(
          (d) => d.status === "completed"
        ).length,
      },
      foodTypeBreakdown: foodTypeStats,
      deliveryBreakdown: deliveryStats,
      recentActivity,
      monthlyTrends: {
        months: last6Months,
        data: last6Months.map((month) => monthlyStats[month]),
      },
      // Live update timestamp
      lastUpdated: new Date().toISOString(),
    };

    console.log("📊 Donation dashboard stats calculated:", stats);

    res.json({
      success: true,
      stats,
    });
  } catch (error) {
    console.error("❌ Error getting donation dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get donation dashboard statistics",
      error: error.message,
    });
  }
};

const getDonationsByStatus = async (req, res) => {
  try {
    const { status } = req.params;
    const validStatuses = [
      "available",
      "reserved",
      "assigned",
      "picked_up",
      "in_transit",
      "completed",
      "expired",
      "cancelled",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const donations = await Donation.find({ status })
      .sort({ createdAt: -1 })
      .populate("donorId", "name email phone");

    res.json({ donations });
  } catch (error) {
    console.error("Error fetching donations by status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const getUrgentDonations = async (req, res) => {
  try {
    const donations = await Donation.find({
      isUrgent: true,
      status: "available",
      verificationStatus: "verified", // Only show verified donations
      expiryDate: { $gt: new Date() },
    })
      .sort({ expiryDate: 1, createdAt: -1 })
      .populate("donorId", "name email phone");

    res.json({ donations });
  } catch (error) {
    console.error("Error fetching urgent donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const getUserRecentDonations = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 10;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const donations = await Donation.find({ donorId: userId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .populate("donorId", "name email")
      .select(
        "title description foodType quantity status createdAt donorId pickupAddress deliveryOption"
      );

    res.json({
      success: true,
      donations,
      count: donations.length,
      userId,
    });
  } catch (error) {
    console.error("Get user recent donations error:", error);
    res.status(500).json({ message: "Server error fetching user donations" });
  }
};

// Centralized utilities already imported at the top

const getDonationsByDeliveryOption = async (req, res) => {
  try {
    const { deliveryOption } = req.params;

    // Handle special routes with consistent values
    let filterOption = deliveryOption;
    if (req.path.includes("/volunteer-deliveries")) {
      filterOption = "Volunteer Delivery";
    } else if (req.path.includes("/paid-deliveries")) {
      filterOption = "Paid Delivery";
    } else if (req.path.includes("/self-deliveries")) {
      filterOption = "Self delivery"; // Make sure this matches
    }

    // Debug: Show all donations in database
    const allDonations = await Donation.find({}).select(
      "title deliveryOption status"
    );
    console.log(
      "🔍 All donations:",
      allDonations.map(
        (d) => `"${d.title}" - ${d.deliveryOption} (${d.status})`
      )
    );

    const donations = await Donation.find({
      deliveryOption: filterOption,
      status: "available",
      verificationStatus: "verified", // Only show verified donations
      assignedTo: { $exists: false }, // Only unassigned donations
    })
      .sort({ createdAt: -1 })
      .populate("donorId", "name email phone");

    console.log(
      `✅ Found ${donations.length} donations with deliveryOption: "${filterOption}"`
    );

    // Add payment amount for paid deliveries
    const enrichedDonations = donations.map((donation) => {
      const donationObj = donation.toObject();

      // Set payment amount for paid deliveries - show delivery person earning after commission
      if (filterOption === "Paid Delivery") {
        const actualPaymentAmount = donationObj.paymentAmount || 100; // What donor actually paid
        const deliveryPersonEarning = actualPaymentAmount * 0.9; // 90% after 10% commission
        donationObj.paymentAmount = deliveryPersonEarning; // Show earning to delivery person
        console.log(
          `💰 Payment: Donor paid ${actualPaymentAmount} PKR, Delivery person gets ${deliveryPersonEarning} PKR`
        );
      }

      return donationObj;
    });

    // Add debug info for each donation
    enrichedDonations.forEach((donation, index) => {
      console.log(`📦 Donation ${index + 1}:`, {
        id: donation._id,
        title: donation.title,
        deliveryOption: donation.deliveryOption,
        status: donation.status,
        paymentAmount: donation.paymentAmount,
        donorName: donation.donorId?.name,
      });
    });

    res.json({
      success: true,
      donations: enrichedDonations,
      filter: filterOption,
      count: donations.length,
    });
  } catch (error) {
    console.error("❌ Error fetching donations by delivery option:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
};

const assignDonation = async (req, res) => {
  try {
    const { id } = req.params;
    const { assigneeId, assignmentType } = req.body;

    if (!assigneeId || !assignmentType) {
      return res
        .status(400)
        .json({ message: "Assignee ID and assignment type are required" });
    }

    if (!["volunteer", "delivery"].includes(assignmentType)) {
      return res.status(400).json({ message: "Invalid assignment type" });
    }

    const donation = await Donation.findById(id).populate(
      "donorId",
      "name email"
    );
    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    if (donation.status !== "available" && donation.status !== "reserved") {
      return res
        .status(400)
        .json({ message: "Donation cannot be assigned in current status" });
    }

    const assignee = await User.findById(assigneeId);
    if (!assignee) {
      return res.status(404).json({ message: "Assignee not found" });
    }

    // Update donation with assignment
    donation.status = "assigned";
    donation.assignedTo = assigneeId;
    donation.assignedAt = new Date();
    donation.assignmentType = assignmentType;

    await donation.save();

    // Send real-time notifications
    try {
      const { getIO } = require("../logic/socket");
      const io = getIO();

      // Notify donor
      io.to(`user_${donation.donorId._id}`).emit("donation_assigned", {
        donationId: donation._id,
        title: donation.title,
        assigneeName: assignee.name,
        assignmentType: assignmentType,
        message: `Your donation has been assigned to ${assignee.name} (${assignmentType})`,
      });

      // Notify assignee
      io.to(`user_${assigneeId}`).emit("donation_assignment", {
        donationId: donation._id,
        title: donation.title,
        donorName: donation.donorId.name,
        message: `You have been assigned a new donation: ${donation.title}`,
      });
    } catch (socketError) {
      console.error("Failed to send assignment notification:", socketError);
    }

    res.json({
      message: "Donation assigned successfully",
      donation: {
        id: donation._id,
        title: donation.title,
        status: donation.status,
        assignedTo: assignee.name,
        assignmentType: assignmentType,
      },
    });
  } catch (error) {
    console.error("Error assigning donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const getDonationStatistics = async (req, res) => {
  try {
    console.log("📊 Getting donation statistics for admin...");

    // Get total counts by verification status
    const totalDonations = await Donation.countDocuments();
    const pendingDonations = await Donation.countDocuments({
      verificationStatus: "pending",
    });
    const verifiedDonations = await Donation.countDocuments({
      verificationStatus: "verified",
    });
    const rejectedDonations = await Donation.countDocuments({
      verificationStatus: "rejected",
    });

    // Get donations by food type
    const donationsByType = await Donation.aggregate([
      {
        $group: {
          _id: "$foodType",
          count: { $sum: 1 },
        },
      },
      {
        $sort: { count: -1 },
      },
    ]);

    // Get donations by month (last 6 months)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const donationsByMonth = await Donation.aggregate([
      {
        $match: {
          createdAt: { $gte: sixMonthsAgo },
        },
      },
      {
        $group: {
          _id: {
            year: { $year: "$createdAt" },
            month: { $month: "$createdAt" },
          },
          count: { $sum: 1 },
        },
      },
      {
        $sort: { "_id.year": 1, "_id.month": 1 },
      },
    ]);

    // Get recent donations (last 7 days)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const recentDonations = await Donation.countDocuments({
      createdAt: { $gte: sevenDaysAgo },
    });

    // Get top donors (by donation count)
    const topDonors = await Donation.aggregate([
      {
        $group: {
          _id: "$donorId",
          count: { $sum: 1 },
          donorName: { $first: "$donorName" },
        },
      },
      {
        $sort: { count: -1 },
      },
      {
        $limit: 5,
      },
      {
        $lookup: {
          from: "users",
          localField: "_id",
          foreignField: "_id",
          as: "donor",
        },
      },
      {
        $project: {
          count: 1,
          donorName: 1,
          email: { $arrayElemAt: ["$donor.email", 0] },
        },
      },
    ]);

    const stats = {
      overview: {
        total: totalDonations,
        pending: pendingDonations,
        verified: verifiedDonations,
        rejected: rejectedDonations,
        recent: recentDonations,
      },
      byType: donationsByType,
      byMonth: donationsByMonth,
      topDonors: topDonors,
    };

    console.log("✅ Donation statistics retrieved successfully");
    res.json({ success: true, stats });
  } catch (error) {
    console.error("❌ Error getting donation statistics:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Complete donation (mark as completed by donor)
const completeDonation = async (req, res) => {
  try {
    const { donationId } = req.params;
    const { notes } = req.body;

    console.log("🎯 Completing donation:", { donationId, notes });

    // Find the donation
    const donation = await Donation.findById(donationId).populate(
      "donorId",
      "name email"
    );

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: "Donation not found",
      });
    }

    // Check if user is the owner of the donation
    if (donation.donorId._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only complete your own donations",
      });
    }

    // Check if donation can be completed
    if (donation.status === "completed") {
      return res.status(400).json({
        success: false,
        message: "Donation is already completed",
      });
    }

    if (donation.status === "cancelled") {
      return res.status(400).json({
        success: false,
        message: "Cannot complete a cancelled donation",
      });
    }

    // Update donation status
    donation.status = "completed";
    donation.completedAt = new Date();
    if (notes) {
      donation.completionNotes = notes;
    }
    await donation.save();

    // Create activity log
    try {
      const ActivityLog = require("../models/ActivityLog");
      await ActivityLog.create({
        userId: req.user._id,
        action: "donation_completed",
        entityType: "donation",
        entityId: donation._id,
        details: {
          donationTitle: donation.title,
          completionNotes: notes,
        },
      });
      console.log("✅ Activity log created for donation completion");
    } catch (activityError) {
      console.error("❌ Failed to create activity log:", activityError);
    }

    // Send notification to delivery person if assigned
    if (donation.assignedTo) {
      try {
        const Notification = require("../models/Notification");
        await Notification.create({
          userId: donation.assignedTo,
          title: "Donation Completed",
          message: `The donation "${donation.title}" has been marked as completed by the donor.`,
          type: "donation_completed",
          data: {
            donationId: donation._id,
            donorName: donation.donorId.name,
          },
        });
        console.log("✅ Notification sent to delivery person");
      } catch (notificationError) {
        console.error("❌ Failed to send notification:", notificationError);
      }
    }

    console.log("🎉 Donation completion process completed successfully");

    res.json({
      success: true,
      message: "Donation marked as completed successfully",
      donation: {
        id: donation._id,
        title: donation.title,
        status: donation.status,
        completedAt: donation.completedAt,
      },
    });
  } catch (error) {
    console.error("❌ Error completing donation:", error);
    res.status(500).json({
      success: false,
      message: "Failed to complete donation",
      error: error.message,
    });
  }
};

module.exports = {
  createDonation,
  getPendingDonations,
  verifyDonation,
  rejectDonation,
  getAvailableDonations,
  getDonationById,
  getUserDonations,

  getDonationsByStatus,
  getUrgentDonations,
  getUserRecentDonations,
  getDonationStats,
  getDonationDashboardStats,
  getDonationsByDeliveryOption,
  assignDonation,
  getAllDonations,
  getDonationStatistics,
  completeDonation,
};
