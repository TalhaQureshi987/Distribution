// -----------------------------------------------------------------------------
// Identity Verification Controller (CARE CONNECT)
// -----------------------------------------------------------------------------
// Handles:
// - Email verification (OTP)
// - Identity document uploads (CNIC + Selfie)
// - Admin approval/rejection
//
// Notes:
// - CNIC images are stored as file paths, not binary data
// - Emails are sent using centralized emailService.js
// -----------------------------------------------------------------------------

const IdentityVerification = require("../models/IdentityVerification");
const User = require("../models/User");
const Notification = require("../models/Notification");
const crypto = require("crypto");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { sendEmail } = require("../services/emailService"); // ✅ centralized email

// -----------------------------------------------------------------------------
// Multer Setup for File Uploads
// -----------------------------------------------------------------------------
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = "uploads/identity/";
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(
      null,
      file.fieldname + "-" + uniqueSuffix + path.extname(file.originalname)
    );
  },
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    console.log("📁 File upload attempt:", {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype,
      size: file.size,
    });

    // Accept common image formats
    const allowedMimeTypes = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/gif",
      "image/webp",
      "image/bmp",
      "image/tiff",
    ];

    // Check if it's a proper image MIME type
    if (
      allowedMimeTypes.includes(file.mimetype) ||
      file.mimetype.startsWith("image/")
    ) {
      console.log("✅ File accepted (image MIME):", file.originalname);
      cb(null, true);
    }
    // Accept octet-stream if filename suggests it's an image (Flutter fallback)
    else if (
      file.mimetype === "application/octet-stream" &&
      file.originalname &&
      /\.(jpg|jpeg|png|gif|webp|bmp|tiff)$/i.test(file.originalname)
    ) {
      console.log(
        "✅ File accepted (octet-stream with image extension):",
        file.originalname
      );
      cb(null, true);
    } else {
      console.log(
        "❌ File rejected:",
        file.originalname,
        "mimetype:",
        file.mimetype
      );
      cb(
        new Error(
          `Invalid file type: ${file.mimetype}. Only image files are allowed.`
        ),
        false
      );
    }
  },
});

// -----------------------------------------------------------------------------
// Send Email Verification Code
// -----------------------------------------------------------------------------
const sendEmailVerification = async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    let verification = await IdentityVerification.findOne({ userId });
    if (!verification) verification = new IdentityVerification({ userId });

    const verificationCode = Math.floor(
      100000 + Math.random() * 900000
    ).toString();
    verification.emailVerificationCode = verificationCode;
    verification.emailVerificationExpires = new Date(
      Date.now() + 15 * 60 * 1000
    ); // 15 minutes
    verification.identityStatus = "pending_email";
    await verification.save();

    // ✅ Send email via service
    await sendEmail(
      user.email,
      "Verify Your Email - CARE CONNECT",
      "verifyEmail",
      { otp: verificationCode }
    );

    res.json({
      success: true,
      message: "Verification code sent to your email",
      expiresIn: 15 * 60,
    });
  } catch (error) {
    console.error("Error sending email verification:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// -----------------------------------------------------------------------------
// Verify Email Code
// -----------------------------------------------------------------------------
const verifyEmailCode = async (req, res) => {
  try {
    const { code } = req.body;
    const userId = req.user._id;

    const verification = await IdentityVerification.findOne({ userId });
    if (!verification)
      return res.status(404).json({ message: "Verification record not found" });

    if (verification.emailVerificationCode !== code)
      return res.status(400).json({ message: "Invalid verification code" });

    if (verification.emailVerificationExpires < new Date())
      return res.status(400).json({ message: "Verification code has expired" });

    verification.emailVerified = true;
    verification.emailVerifiedAt = new Date();
    verification.identityStatus = "email_verified";
    verification.emailVerificationCode = undefined;
    verification.emailVerificationExpires = undefined;
    await verification.save();

    const user = await User.findById(userId);
    user.emailVerified = true;
    user.identityVerificationId = verification._id;
    await user.save();

    res.json({
      success: true,
      message: "Email verified successfully",
      nextStep: "identity_documents",
    });
  } catch (error) {
    console.error("Error verifying email code:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// -----------------------------------------------------------------------------
// Upload Identity Documents
// -----------------------------------------------------------------------------
const uploadDocuments = async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId);
    const { cnicNumber } = req.body; // Extract CNIC number from request body

    // Check if user's email is verified (use User model field)
    if (!user.isEmailVerified) {
      return res.status(400).json({
        success: false,
        message:
          "Email verification required first. Please verify your email before uploading identity documents.",
      });
    }

    let verification = await IdentityVerification.findOne({ userId });
    if (!verification) {
      verification = new IdentityVerification({ userId });
    }

    if (!verification.canAttemptVerification()) {
      console.log("❌ Too many verification attempts for user:", user.email);

      // Reset attempts if it's been more than the cooldown period
      const cooldownPeriod = 1 * 60 * 60 * 1000; // 1 hour
      const timeSinceLastAttempt =
        Date.now() - verification.lastAttemptAt?.getTime();

      if (timeSinceLastAttempt > cooldownPeriod) {
        console.log("🔄 Resetting verification attempts after cooldown period");
        verification.verificationAttempts = 0;
        verification.lastAttemptAt = null;
        await verification.save();
      } else {
        const remainingTime = Math.ceil(
          (cooldownPeriod - timeSinceLastAttempt) / (60 * 1000)
        ); // minutes
        return res.status(429).json({
          success: false,
          message: `Too many verification attempts. Please try again in ${remainingTime} minutes.`,
          remainingMinutes: remainingTime,
        });
      }
    }

    const files = req.files;
    if (!files || !files.cnicFront || !files.cnicBack || !files.selfie)
      return res
        .status(400)
        .json({
          message: "All documents required: CNIC front, CNIC back, and selfie",
        });

    verification.cnicFrontImage = files.cnicFront[0].path;
    verification.cnicBackImage = files.cnicBack[0].path;
    verification.selfieImage = files.selfie[0].path;
    verification.identityStatus = "documents_uploaded";
    verification.incrementAttempt();

    await verification.save();

    // Update user's identity verification status and CNIC number
    user.identityVerificationStatus = "pending";
    user.cnicFrontPhoto = files.cnicFront[0].path;
    user.cnicBackPhoto = files.cnicBack[0].path;
    user.selfiePhoto = files.selfie[0].path;

    // Save CNIC number if provided
    if (cnicNumber && cnicNumber.trim()) {
      user.cnicNumber = cnicNumber.trim();
    }

    await user.save();

    console.log("✅ Documents uploaded successfully for user:", user.email);
    console.log("📄 CNIC Number saved:", user.cnicNumber);
    console.log("📁 Files saved:", {
      cnicFront: files.cnicFront[0].path,
      cnicBack: files.cnicBack[0].path,
      selfie: files.selfie[0].path,
    });

    // Create notification for admin
    const notification = new Notification({
      userId: user._id,
      title: "Identity Documents Uploaded",
      message:
        "Your identity verification documents have been uploaded and are pending admin review.",
      type: "identity_verification",
      priority: "medium",
    });
    await notification.save();

    res.json({
      success: true,
      message: "Submission done! Wait for admin verification.",
      status: "pending_review",
    });
  } catch (error) {
    console.error("❌ Error uploading documents:", error);
    console.error("❌ Error stack:", error.stack);
    console.error("❌ Error details:", {
      message: error.message,
      name: error.name,
      userId: req.user?._id,
      files: req.files ? Object.keys(req.files) : "No files",
      body: req.body,
    });

    res.status(500).json({
      success: false,
      message: "Server error during document upload",
      error:
        process.env.NODE_ENV === "development"
          ? error.message
          : "Internal server error",
    });
  }
};

// -----------------------------------------------------------------------------
// Get Verification Status (User)
// -----------------------------------------------------------------------------
const getVerificationStatus = async (req, res) => {
  try {
    const userId = req.user._id;
    const verification = await IdentityVerification.findOne({
      userId,
    }).populate("reviewedBy", "name email");

    if (!verification) {
      return res.json({
        status: "not_started",
        emailVerified: false,
        identityVerified: false,
      });
    }

    res.json({
      status: verification.identityStatus,
      emailVerified: verification.emailVerified,
      identityVerified: verification.identityStatus === "verified",
      documentsUploaded: !!(
        verification.cnicFrontImage &&
        verification.cnicBackImage &&
        verification.selfieImage
      ),
      reviewedAt: verification.reviewedAt,
      reviewedBy: verification.reviewedBy,
      rejectionReason: verification.rejectionReason,
      canRetry: verification.canAttemptVerification(),
      attemptsLeft: Math.max(0, 5 - verification.verificationAttempts),
    });
  } catch (error) {
    console.error("Error getting verification status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// -----------------------------------------------------------------------------
// Admin: Get Pending Verifications
// -----------------------------------------------------------------------------
const getPendingVerifications = async (req, res) => {
  try {
    const verifications = await IdentityVerification.find({
      identityStatus: "documents_uploaded",
      cnicFrontImage: { $exists: true },
      cnicBackImage: { $exists: true },
      selfieImage: { $exists: true },
    })
      .populate("userId", "name email cnic roles")
      .sort({ createdAt: -1 });

    res.json({ verifications });
  } catch (error) {
    console.error("Error getting pending verifications:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// -----------------------------------------------------------------------------
// Admin: Reject Verification
// -----------------------------------------------------------------------------
const rejectVerification = async (req, res) => {
  try {
    const { verificationId } = req.params;
    const { rejectionReason, adminNotes } = req.body;

    const verification = await IdentityVerification.findById(
      verificationId
    ).populate("userId");
    if (!verification)
      return res.status(404).json({ message: "Verification not found" });

    verification.identityStatus = "rejected";
    verification.reviewedBy = req.user._id;
    verification.reviewedAt = new Date();
    verification.rejectionReason = rejectionReason;
    verification.adminNotes = adminNotes;
    await verification.save();

    const notification = new Notification({
      userId: verification.userId._id,
      title: "Identity Verification Rejected",
      message:
        adminNotes ||
        "Your identity verification was rejected. Please review and resubmit.",
      type: "identity_rejected",
      priority: "high",
    });
    await notification.save();

    res.json({
      success: true,
      message: "Identity verification rejected",
      rejectionReason,
    });
  } catch (error) {
    console.error("Error rejecting verification:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// -----------------------------------------------------------------------------
// Admin: Approve Verification
// -----------------------------------------------------------------------------
const approveVerification = async (req, res) => {
  try {
    const { verificationId } = req.params;
    const { adminNotes } = req.body;

    const verification = await IdentityVerification.findById(
      verificationId
    ).populate("userId");
    if (!verification)
      return res.status(404).json({ message: "Verification not found" });

    verification.identityStatus = "verified";
    verification.reviewedBy = req.user._id;
    verification.reviewedAt = new Date();
    verification.adminNotes = adminNotes;
    await verification.save();

    const user = verification.userId;
    user.isIdentityVerified = true;
    user.identityVerificationStatus = "approved";
    await user.save();

    const notification = new Notification({
      userId: user._id,
      title: "Identity Verified!",
      message: "Your identity has been verified successfully.",
      type: "identity_verified",
      priority: "high",
    });
    await notification.save();

    // Send real-time Socket.IO notification
    const io = req.app.locals.io;
    if (io) {
      console.log(
        `🎯 SOCKET: Sending identity verification approval to user_${user._id}`
      );

      const notificationData = {
        type: "identity_verified",
        title: "Identity Verified!",
        message:
          "Your identity verification has been approved. You can now access all features.",
        user: {
          _id: user._id,
          name: user.name,
          email: user.email,
          isIdentityVerified: true,
          identityVerificationStatus: "approved",
        },
      };

      // Emit to user's room
      io.to(`user_${user._id}`).emit("verification_approved", notificationData);

      // Fallback broadcast
      io.emit("user_verification_update", {
        userId: user._id,
        ...notificationData,
      });

      console.log(
        `✅ SOCKET: Identity verification notification sent to user_${user._id}`
      );
    } else {
      console.log("❌ SOCKET: Socket.IO not available");
    }

    // ✅ Send email via service
    await sendEmail(
      user.email,
      "Identity Verified - CARE CONNECT",
      "identityApproved"
    );

    res.json({
      success: true,
      message: "Identity verification approved",
      user: { id: user._id, name: user.name, identityVerified: true },
    });
  } catch (error) {
    console.error("Error approving verification:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// -----------------------------------------------------------------------------
// Exports
// -----------------------------------------------------------------------------
module.exports = {
  sendEmailVerification,
  verifyEmailCode,
  uploadDocuments: [
    upload.fields([
      { name: "cnicFront", maxCount: 1 },
      { name: "cnicBack", maxCount: 1 },
      { name: "selfie", maxCount: 1 },
    ]),
    uploadDocuments,
  ],
  getVerificationStatus,
  getPendingVerifications,
  approveVerification,
  rejectVerification,
};
