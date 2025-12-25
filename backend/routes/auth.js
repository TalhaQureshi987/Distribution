const express = require("express");
const router = express.Router();
const authController = require("../controllers/authController");
const { protect, admin } = require("../middleware/authMiddleware");
const User = require("../models/User");
const Payment = require("../models/Payment");

// Register, verify, login
router.post("/register", authController.register);
router.post("/verify-email", authController.verifyEmailOTP);
router.post("/verify-email-otp", authController.verifyEmailOTP);
router.post("/send-otp", authController.sendEmailOTP);
router.post("/login", authController.login);

// Profile
router.get("/profile", protect, authController.getProfile);

// Token refresh
router.post("/refresh-token", authController.refreshToken);

// Identity verification
router.post(
  "/identity/submit",
  protect,
  authController.submitIdentityVerification
);
router.post(
  "/identity/approve",
  protect,
  admin,
  authController.approveIdentityVerification
);
router.post(
  "/identity/reject",
  protect,
  admin,
  authController.rejectIdentityVerification
);

// Payments
router.post("/simulate-payment", protect, authController.simulatePayment);
router.post(
  "/complete-registration-payment",
  authController.completeRegistrationPayment
);

// Admin: users
router.get("/admin/users", protect, admin, async (req, res) => {
  try {
    const users = await User.find().select("-password -emailOTP");
    res.json({ success: true, users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Admin: delete user
router.delete("/admin/users/:id", protect, admin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found" });

    // Prevent deletion of admin users
    if (user.role === "admin") {
      return res
        .status(403)
        .json({ success: false, message: "Cannot delete admin users" });
    }

    await User.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: "User deleted successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Admin: update user (merged route)
router.patch("/admin/users/:id", protect, admin, async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    }).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Admin: payments
router.get("/admin/payments", protect, admin, async (req, res) => {
  try {
    const payments = await Payment.find().sort({ createdAt: -1 }).lean();
    const result = await Promise.all(
      payments.map(async (payment) => {
        const user = await User.findById(payment.userId).select(
          "name email role"
        );
        return {
          ...payment,
          user: user
            ? {
                _id: user._id,
                name: user.name,
                email: user.email,
                role: user.role,
              }
            : null,
        };
      })
    );
    res.json({ success: true, payments: result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Admin: statistics
router.get("/admin/stats", protect, admin, async (req, res) => {
  try {
    const totalUsers = await User.countDocuments({ role: { $nin: ["admin"] } });
    const approvedUsers = await User.countDocuments({
      status: "approved",
      role: { $nin: ["admin"] },
    });
    const pendingUsers = await User.countDocuments({
      status: "pending",
      role: { $nin: ["admin"] },
    });
    const rejectedUsers = await User.countDocuments({
      status: "rejected",
      role: { $nin: ["admin"] },
    });

    const donors = await User.countDocuments({ role: "donor" });
    const requesters = await User.countDocuments({ role: "requester" });
    const volunteers = await User.countDocuments({ role: "volunteer" });
    const delivery = await User.countDocuments({ role: "delivery" });

    const verifiedUsers = await User.countDocuments({
      identityVerificationStatus: "approved",
    });
    const pendingVerifications = await User.countDocuments({
      identityVerificationStatus: "pending",
    });

    res.json({
      success: true,
      stats: {
        totalUsers,
        approvedUsers,
        pendingUsers,
        rejectedUsers,
        donors,
        requesters,
        volunteers,
        delivery,
        verifiedUsers,
        pendingVerifications,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Admin: verification events (Server-Sent Events)
router.get("/admin/verification-events", protect, admin, (req, res) => {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Cache-Control",
  });

  res.write(
    'data: {"type": "connected", "message": "Connected to verification events"}\n\n'
  );

  const heartbeat = setInterval(() => {
    res.write(
      'data: {"type": "heartbeat", "timestamp": "' +
        new Date().toISOString() +
        '"}\n\n'
    );
  }, 30000);

  req.on("close", () => {
    clearInterval(heartbeat);
  });
});

// Admin: identity verification approval/rejection
router.patch(
  "/admin/identity-verifications/:userId/approve",
  protect,
  admin,
  async (req, res) => {
    try {
      const user = await User.findById(req.params.userId);
      if (!user)
        return res
          .status(404)
          .json({ success: false, message: "User not found" });

      // Set permanent verified status - once approved, always verified
      user.identityVerificationStatus = "approved";
      user.status = "approved";
      user.verifiedAt = new Date();
      user.isIdentityVerified = true;
      await user.save();

      console.log(
        `🎯 SOCKET: Sending identity verification update to user_${user._id}`
      );

      // Socket notification
      try {
        const { getIO } = require("../logic/socket");
        const io = getIO();

        const notificationData = {
          type: "identity_verified",
          title: "Identity Verified!",
          message:
            "Your identity verification has been approved. You can now access all features.",
          user: {
            _id: user._id,
            name: user.name,
            email: user.email,
            identityVerificationStatus: "approved",
            status: "approved",
            isIdentityVerified: true,
          },
          timestamp: new Date().toISOString(),
        };

        console.log(`🎯 SOCKET: Notification data:`, notificationData);
        console.log(`🎯 SOCKET: Emitting to room: user_${user._id}`);

        io.to(`user_${user._id}`).emit("identity_verified", notificationData);

        // Also emit to all connected sockets for this user (fallback)
        io.sockets.sockets.forEach((socket) => {
          if (socket.userId === user._id.toString()) {
            console.log(
              `🎯 SOCKET: Direct emit to socket ${socket.id} for user ${socket.userId}`
            );
            socket.emit("identity_verified", notificationData);
          }
        });
      } catch (socketError) {
        console.error("Socket error:", socketError);
      }

      res.json({ success: true, message: "User verified successfully" });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

router.patch(
  "/admin/identity-verifications/:userId/reject",
  protect,
  admin,
  async (req, res) => {
    try {
      const { reason } = req.body;
      const user = await User.findById(req.params.userId);
      if (!user)
        return res
          .status(404)
          .json({ success: false, message: "User not found" });

      user.identityVerificationStatus = "rejected";
      user.status = "rejected";
      user.rejectionReason = reason;
      await user.save();

      res.json({ success: true, message: "Identity rejected", reason });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Admin: identity verifications
router.get(
  "/admin/identity-verifications/pending",
  protect,
  admin,
  async (req, res) => {
    try {
      const pendingUsers = await User.find({
        identityVerificationStatus: "pending",
        $or: [
          { cnicFrontPhoto: { $exists: true, $ne: null } },
          { cnicBackPhoto: { $exists: true, $ne: null } },
          { selfiePhoto: { $exists: true, $ne: null } },
        ],
      }).select(
        "name email role cnicNumber cnicFrontPhoto cnicBackPhoto selfiePhoto createdAt identityVerificationStatus"
      );

      res.json({ success: true, pendingVerifications: pendingUsers });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

router.get(
  "/admin/identity-verifications/all",
  protect,
  admin,
  async (req, res) => {
    try {
      const allVerifications = await User.find({
        $or: [
          { cnicFrontPhoto: { $exists: true, $ne: null } },
          { cnicBackPhoto: { $exists: true, $ne: null } },
        ],
      })
        .select(
          "name email phone address role status cnicNumber cnicFrontPhoto cnicBackPhoto createdAt identityVerificationStatus isEmailVerified paymentStatus applicationFeePaid paymentAmount paymentCurrency"
        )
        .sort({ createdAt: -1 });

      res.json({ success: true, allVerifications });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// User status for frontend permissions
router.get("/user-status", protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select(
      "-password -emailOTP"
    );
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found" });

    // Check if user is permanently verified
    const isVerified =
      user.identityVerificationStatus === "approved" ||
      user.isIdentityVerified === true;

    const permissions = {
      canDonate: user.status === "approved" && user.role === "donor",
      canRequest:
        user.status === "approved" && user.role === "requester" && isVerified,
      canVolunteer:
        user.status === "approved" && user.role === "volunteer" && isVerified,
      canDelivery:
        user.status === "approved" && user.role === "delivery" && isVerified,
    };

    // Add verification status info
    const verificationInfo = {
      needsIdentityVerification: !isVerified && !user.cnicNumber,
      identityPending: user.identityVerificationStatus === "pending",
      identityVerified: isVerified,
      verifiedAt: user.verifiedAt,
    };

    res.json({ success: true, user, permissions, verificationInfo });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
