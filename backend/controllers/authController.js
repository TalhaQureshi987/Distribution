const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Payment = require("../models/Payment");
const { sendEmail } = require("../services/emailService");
const { v4: uuidv4 } = require("uuid");
const { authLogger: logger } = require("../config/logger");

// Helper: generate OTP
const generateOTP = () =>
  Math.floor(100000 + Math.random() * 900000).toString();

// Register user with OTP
const register = async (req, res) => {
  try {
    const { name, email, password, phone, role, address } = req.body;

    if (!name || !email || !password || !phone || !role || !address) {
      return res.status(400).json({
        success: false,
        message: "Please provide all required fields",
      });
    }

    logger.info(`New registration attempt - Email: ${email}, Role: ${role}`);

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "Email already registered",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const otp = generateOTP();
    const otpExpiry = new Date(Date.now() + 5 * 60 * 1000);

    const newUser = new User({
      name,
      email,
      password: hashedPassword,
      phone,
      role,
      address,
      emailOTP: otp,
      emailOTPExpires: otpExpiry,
      isEmailVerified: false,
      status: "pending",
    });
    await newUser.save();

    await sendEmail(email, "Verify your email", "verifyEmailOTP", {
      name,
      otp,
      role,
    });

    res.status(201).json({
      success: true,
      message: "User registered, please verify OTP",
      userId: newUser._id,
      email: newUser.email,
      requiresPayment: ["requester", "delivery"].includes(role),
      user: {
        _id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        role: newUser.role,
        status: newUser.status,
        isEmailVerified: newUser.isEmailVerified,
      },
    });
  } catch (error) {
    logger.error("Registration error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Verify Email OTP
const verifyEmailOTP = async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res
        .status(400)
        .json({ success: false, message: "Email and OTP are required" });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    if (user.emailOTPExpires < new Date()) {
      return res.status(400).json({
        success: false,
        message: "Verification code has expired. Please request a new one.",
      });
    }

    // Normalize both values to strings and trim whitespace
    const storedOTP = user.emailOTP ? user.emailOTP.toString().trim() : "";
    const receivedOTP = otp ? otp.toString().trim() : "";

    logger.info(
      `🔍 OTP Debug - Stored: "${storedOTP}" (${typeof user.emailOTP}), Received: "${receivedOTP}" (${typeof otp})`
    );

    if (storedOTP !== receivedOTP) {
      logger.warn(
        `❌ OTP mismatch - Expected: "${storedOTP}", Received: "${receivedOTP}", Email: ${email}`
      );
      return res
        .status(400)
        .json({ success: false, message: "Invalid verification code" });
    }

    logger.info(`✅ OTP verified successfully for ${email}`);

    user.isEmailVerified = true;
    user.emailOTP = undefined;
    user.emailOTPExpires = undefined;
    if (user.status === "pending") user.status = "email_verified";
    await user.save();

    // Send identity verification guidance email after email verification
    try {
      await sendEmail(
        user.email,
        "Identity verification required",
        "identityVerificationRequest",
        { name: user.name }
      );
    } catch (mailErr) {
      logger.warn(
        `Email verified but failed to send identity guidance email: ${
          mailErr?.message || mailErr
        }`
      );
    }

    res.json({ success: true, message: "Email verified successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Send Email OTP again
const sendEmailOTP = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res
        .status(400)
        .json({ success: false, message: "Email is required" });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    const otp = generateOTP();
    const otpExpiry = new Date(Date.now() + 5 * 60 * 1000);

    user.emailOTP = otp;
    user.emailOTPExpires = otpExpiry;
    await user.save();

    await sendEmail(email, "Verify your email", "verifyEmailOTP", {
      name: user.name,
      otp,
      role: user.role,
    });

    res.json({
      success: true,
      message: "Verification code sent to your email",
    });
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: "Failed to send verification code" });
  }
};

// Login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    logger.info(`Login attempt for email: ${email}`);

    if (!email || !password) {
      return res
        .status(400)
        .json({ success: false, message: "Email and password are required" });
    }

    const user = await User.findOne({ email }).select("+password");
    if (!user) {
      logger.warn(`❌ Login failed - User not found: ${email}`);
      return res
        .status(401)
        .json({ success: false, message: "Invalid email or password" });
    }

    logger.info(
      `✅ User found: ${email}, Email verified: ${user.isEmailVerified}, Status: ${user.status}`
    );

    if (!user.isEmailVerified) {
      return res.status(403).json({
        success: false,
        message: "Please verify your email before logging in",
      });
    }

    if (["rejected", "suspended"].includes(user.status)) {
      return res.status(403).json({
        success: false,
        message:
          "Your account has been rejected or suspended. Please contact support.",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    logger.info(`🔑 Password comparison - Match: ${isMatch}`);

    // Additional bcrypt debugging for salt compatibility
    if (!isMatch) {
      logger.info(
        `🔍 Bcrypt Debug - Testing hash generation with provided password`
      );
      const testHash10 = await bcrypt.hash(password, 10);
      const testMatch10 = await bcrypt.compare(password, testHash10);
      logger.info(
        `🔍 Salt 10 test - Hash: ${testHash10.substring(
          0,
          20
        )}..., Match: ${testMatch10}`
      );

      // Check if this is a salt compatibility issue
      if (testMatch10) {
        logger.info(`✅ Password is correct but salt mismatch detected`);
        // Re-hash the password with salt 10 and update user
        const newHash = await bcrypt.hash(password, 10);
        user.password = newHash;
        await user.save();
        logger.info(`🔄 Password re-hashed with salt 10 for compatibility`);
      } else {
        logger.warn(`❌ Password mismatch for user: ${email}`);
        return res
          .status(401)
          .json({ success: false, message: "Invalid email or password" });
      }
    }

    const token = jwt.sign(
      { userId: user._id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { algorithm: "HS512", expiresIn: "7d" }
    );

    user.lastLogin = new Date();
    await user.save();

    res.json({
      success: true,
      message: "Login successful",
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status,
        isEmailVerified: user.isEmailVerified,
        identityVerificationStatus: user.identityVerificationStatus,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    logger.error("Login error:", error);
    res.status(500).json({
      success: false,
      message: "Login failed. Please try again later.",
    });
  }
};

// Get profile
const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    res.json({ user });
  } catch (error) {
    res.status(500).json({ message: "Server error" });
  }
};

// Submit identity verification
const submitIdentityVerification = async (req, res) => {
  try {
    const { cnicNumber } = req.body;
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found" });

    // Check if identity is already verified - prevent re-submission
    if (user.identityVerificationStatus === "approved") {
      return res.json({
        success: true,
        message: "Identity already verified",
        alreadyVerified: true,
      });
    }

    // Check if identity is pending - prevent duplicate submissions
    if (user.identityVerificationStatus === "pending") {
      return res.json({
        success: true,
        message: "Identity verification is under review",
        isPending: true,
      });
    }

    if (!cnicNumber) {
      return res
        .status(400)
        .json({ success: false, message: "CNIC number is required" });
    }

    if (!req.files?.cnicFront || !req.files?.cnicBack) {
      return res.status(400).json({
        success: false,
        message: "Both front and back CNIC images are required",
      });
    }

    user.cnicNumber = cnicNumber;
    user.cnicFrontPhoto = req.files.cnicFront[0].path;
    user.cnicBackPhoto = req.files.cnicBack[0].path;
    user.identityVerificationStatus = "pending";
    user.identitySubmittedAt = new Date();
    await user.save();

    res.json({
      success: true,
      message: "Identity verification submitted successfully",
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Approve identity
const approveIdentityVerification = async (req, res) => {
  try {
    const { userId } = req.body;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    user.identityVerificationStatus = "approved";
    user.status = "approved";
    await user.save();

    // Socket notification (single consolidated event)
    try {
      const { getIO } = require("../logic/socket");
      const io = getIO();

      console.log(
        `🎯 SOCKET: Sending identity verification update to user_${user._id}`
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

    res.json({ message: "User verified successfully" });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Reject identity
const rejectIdentityVerification = async (req, res) => {
  try {
    const { userId, reason } = req.body;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    user.identityVerificationStatus = "rejected";
    user.status = "rejected";
    user.rejectionReason = reason;
    await user.save();

    res.json({ message: "Identity rejected", reason });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Simulate payment
const simulatePayment = async (req, res) => {
  try {
    const { userId, amount } = req.body;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    user.paymentStatus = "paid";
    await user.save();

    const payment = new Payment({
      userId,
      amount,
      status: "paid",
      transactionId: uuidv4(),
    });
    await payment.save();

    res.json({ message: "Payment simulated successfully" });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Complete registration payment
const completeRegistrationPayment = async (req, res) => {
  try {
    const { userId, paymentIntentId, amount } = req.body;

    // Validate required fields
    if (!userId || !paymentIntentId || !amount) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields: userId, paymentIntentId, amount",
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // SECURITY: Validate payment with Stripe
    const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

    try {
      // Retrieve and validate payment intent from Stripe
      const paymentIntent = await stripe.paymentIntents.retrieve(
        paymentIntentId
      );

      // Verify payment was successful
      if (paymentIntent.status !== "succeeded") {
        return res.status(400).json({
          success: false,
          message: `Payment not completed. Status: ${paymentIntent.status}`,
        });
      }

      // Verify payment amount matches expected amount
      const expectedAmount = Math.round(amount * 100); // Convert to cents
      if (paymentIntent.amount !== expectedAmount) {
        return res.status(400).json({
          success: false,
          message: `Payment amount mismatch. Expected: ${expectedAmount}, Received: ${paymentIntent.amount}`,
        });
      }

      // Verify payment is for registration (check metadata)
      if (paymentIntent.metadata?.type !== "registration_fee") {
        return res.status(400).json({
          success: false,
          message: "Invalid payment type. Expected registration fee.",
        });
      }

      // Check if payment was already processed
      const existingPayment = await Payment.findOne({
        stripePaymentIntentId: paymentIntentId,
      });

      if (existingPayment) {
        return res.status(400).json({
          success: false,
          message: "Payment already processed",
        });
      }

      // Create payment record with actual Stripe data
      const paymentRecord = new Payment({
        userId: user._id,
        type: "registration_fee",
        stripePaymentIntentId: paymentIntentId,
        stripeChargeId: paymentIntent.latest_charge,
        amount: amount,
        currency: "PKR",
        status: "completed",
        description: `Registration fee for ${user.role}`,
        processedAt: new Date(),
        metadata: {
          stripePaymentIntentId: paymentIntentId,
          stripeChargeId: paymentIntent.latest_charge,
          paymentMethod: paymentIntent.payment_method,
          receiptUrl: paymentIntent.charges?.data?.[0]?.receipt_url,
        },
      });

      await paymentRecord.save();

      // Update user payment status
      user.paymentStatus = "paid";
      user.applicationFeePaid = true;
      user.paymentAmount = amount;
      user.paymentCurrency = "PKR";
      user.paymentDate = new Date();
      await user.save();

      logger.info(
        `Registration payment completed for user ${user.email}: ${paymentIntentId}`
      );

      res.json({
        success: true,
        message: "Payment completed successfully",
        user: {
          _id: user._id,
          name: user.name,
          email: user.email,
          paymentStatus: user.paymentStatus,
          paymentAmount: user.paymentAmount,
          paymentCurrency: user.paymentCurrency,
        },
        paymentDetails: {
          paymentIntentId: paymentIntentId,
          amount: amount,
          status: "completed",
        },
      });
    } catch (stripeError) {
      logger.error("Stripe validation error:", stripeError);
      return res.status(400).json({
        success: false,
        message: `Payment validation failed: ${stripeError.message}`,
      });
    }
  } catch (error) {
    logger.error("Registration payment completion error:", error);
    res.status(500).json({
      success: false,
      message: "Server error processing payment",
    });
  }
};

// Refresh token endpoint
const refreshToken = async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: "Token is required",
      });
    }

    // Verify the existing token (even if expired, we can still decode it)
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (error) {
      // If token is expired, try to decode without verification
      if (error.name === "TokenExpiredError") {
        decoded = jwt.decode(token);
        if (!decoded) {
          return res.status(401).json({
            success: false,
            message: "Invalid token",
          });
        }
      } else {
        return res.status(401).json({
          success: false,
          message: "Invalid token",
        });
      }
    }

    // Find the user
    const user = await User.findById(decoded.userId).select("-password");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    // Generate new token
    const newToken = jwt.sign(
      { userId: user._id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { algorithm: "HS512", expiresIn: "7d" }
    );

    logger.info(`Token refreshed for user: ${user.email}`);

    res.json({
      success: true,
      token: newToken,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    logger.error("Token refresh error:", error);
    res.status(500).json({
      success: false,
      message: "Token refresh failed",
    });
  }
};

module.exports = {
  register,
  verifyEmailOTP,
  sendEmailOTP,
  login,
  getProfile,
  submitIdentityVerification,
  approveIdentityVerification,
  rejectIdentityVerification,
  simulatePayment,
  completeRegistrationPayment,
  refreshToken,
};
