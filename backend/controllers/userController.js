// controllers/userController.js
const User = require("../models/User");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const nodemailer = require("nodemailer");

const JWT_SECRET = process.env.JWT_SECRET;

// ================= PROFILE =================
const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-password");
    res.json({ user });
  } catch (error) {
    res.status(500).json({ message: "Error fetching profile", error: error.message });
  }
};
const getUserActivity = async (req, res) => {
  try {
    const { userId } = req.params;
    // Example: return activity logs
    const user = await User.findById(userId).select("activityLogs");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user.activityLogs);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Get user donations
const getUserDonations = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).select("donations");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user.donations);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Get user requests
const getUserRequests = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).select("requests");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user.requests);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { name } = req.body;
    const user = await User.findByIdAndUpdate(
      req.user._id,
      { name },
      { new: true }
    ).select("-password");
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: "Error updating profile", error: error.message });
  }
};

// ================= PASSWORD =================
const changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) return res.status(400).json({ message: "Incorrect old password" });

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.status(200).json({ message: "Password updated successfully" });
  } catch (error) {
    res.status(500).json({ message: "Error changing password", error: error.message });
  }
};

// ================= EMAIL =================
const changeEmail = async (req, res) => {
  try {
    const { newEmail } = req.body;
    const existingUser = await User.findOne({ email: newEmail });
    if (existingUser) return res.status(400).json({ message: "Email already in use" });

    const user = await User.findById(req.user._id);
    user.email = newEmail;
    user.isVerified = false;
    await user.save();

    res.status(200).json({ message: "Email updated, please verify new email" });
  } catch (error) {
    res.status(500).json({ message: "Error changing email", error: error.message });
  }
};

// ================= FORGOT / RESET PASSWORD =================
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: "User not found" });

    const token = jwt.sign({ id: user._id }, JWT_SECRET, { expiresIn: "15m" });
    user.resetToken = token;
    user.resetTokenExpires = Date.now() + 15 * 60 * 1000;
    await user.save();

    // send email
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
    });
    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: email,
      subject: "Password Reset",
      text: `Use this token to reset password: ${token}`,
    });

    res.status(200).json({ message: "Password reset email sent" });
  } catch (error) {
    res.status(500).json({ message: "Error sending reset email", error: error.message });
  }
};

const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(decoded.id);

    if (!user || user.resetToken !== token || user.resetTokenExpires < Date.now()) {
      return res.status(400).json({ message: "Invalid or expired token" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    user.resetToken = undefined;
    user.resetTokenExpires = undefined;
    await user.save();

    res.status(200).json({ message: "Password reset successful" });
  } catch (error) {
    res.status(500).json({ message: "Error resetting password", error: error.message });
  }
};

// ================= ACCOUNT =================
const deleteAccount = async (req, res) => {
  try {
    await User.findByIdAndDelete(req.user._id);
    res.status(200).json({ message: "Account deleted successfully" });
  } catch (error) {
    res.status(500).json({ message: "Error deleting account", error: error.message });
  }
};

// ================= TOKENS =================
const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(401).json({ message: "Refresh token required" });

    jwt.verify(refreshToken, JWT_SECRET, (err, user) => {
      if (err) return res.status(403).json({ message: "Invalid refresh token" });

      const newAccessToken = jwt.sign(
        { id: user.id, role: user.role },
        JWT_SECRET,
        { expiresIn: "1h" }
      );
      res.json({ accessToken: newAccessToken });
    });
  } catch (error) {
    res.status(500).json({ message: "Error refreshing token", error: error.message });
  }
};

const logout = async (req, res) => {
  res.status(200).json({ message: "Logged out successfully" });
};

// Get user statistics
const getUserStatistics = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    // Calculate statistics based on user data
    const stats = {
      totalDonations: user.donations?.length || 0,
      totalRequests: user.requests?.length || 0,
      helpedFamilies: 0, // Calculate based on completed donations/requests
      impactHours: (user.donations?.length || 0) * 2 + (user.requests?.length || 0) * 1
    };

    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Get user payment statistics
const getUserPaymentStatistics = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    // Calculate payment statistics
    const paymentStats = {
      registrationFee: user.registrationFeePaid ? 500 : 0,
      deliveryFeesPaid: user.deliveryFeesPaid || 0,
      requesterFeesPaid: user.requesterFeesPaid || 0,
      deliveryEarnings: user.deliveryEarnings || 0,
      totalPayments: (user.registrationFeePaid ? 1 : 0) + (user.deliveryPayments?.length || 0) + (user.requesterPayments?.length || 0),
      totalAmount: (user.registrationFeePaid ? 500 : 0) + (user.deliveryFeesPaid || 0) + (user.requesterFeesPaid || 0)
    };

    res.json({ success: true, data: paymentStats });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Get user payments feed
const getUserPayments = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    let payments = [];

    // Add registration payment if paid
    if (user.registrationFeePaid) {
      payments.push({
        id: 'reg_payment_' + userId,
        type: 'registration',
        action: 'Registration Fee Paid',
        amount: 500,
        date: user.registrationDate || user.createdAt,
        status: 'completed'
      });
    }

    // Add delivery payments
    if (user.deliveryPayments) {
      payments = payments.concat(user.deliveryPayments.map(payment => ({
        ...payment,
        type: 'delivery_fee',
        action: 'Delivery Fee Paid'
      })));
    }

    // Add requester payments
    if (user.requesterPayments) {
      payments = payments.concat(user.requesterPayments.map(payment => ({
        ...payment,
        type: 'requester_fee',
        action: 'Request Fee Paid'
      })));
    }

    // Add delivery earnings
    if (user.deliveryEarnings && user.deliveryEarnings > 0) {
      payments.push({
        id: 'earnings_' + userId,
        type: 'earnings',
        action: 'Delivery Earnings',
        amount: user.deliveryEarnings,
        date: new Date(),
        status: 'completed'
      });
    }

    // Sort by date (newest first)
    payments.sort((a, b) => new Date(b.date) - new Date(a.date));

    res.json({ success: true, data: payments });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Get role-based user payments
const getRoleBasedUserPayments = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    const Payment = require('../models/Payment');
    let payments = [];
    let paymentStats = {};

    // Get user roles (can have multiple roles)
    const userRoles = user.roles || [user.role];

    console.log(`🔍 Getting payments for user ${userId} with roles: ${userRoles.join(', ')}`);

    // DELIVERY PERSONNEL - Show delivery payments with details (distance, fee, commission)
    if (userRoles.includes('delivery')) {
      console.log('📦 Fetching delivery payments...');

      const deliveryPayments = await Payment.find({
        userId: userId,
        type: { $in: ['delivery_charge', 'delivery_commission'] }
      }).sort({ createdAt: -1 }).limit(50);

      const deliveryStats = {
        totalDeliveries: deliveryPayments.filter(p => p.type === 'delivery_charge').length,
        totalEarnings: deliveryPayments
          .filter(p => p.type === 'delivery_commission')
          .reduce((sum, p) => sum + p.amount, 0),
        totalDistance: deliveryPayments
          .filter(p => p.metadata?.distance)
          .reduce((sum, p) => sum + (p.metadata.distance || 0), 0),
        averageDistance: 0
      };

      if (deliveryStats.totalDeliveries > 0) {
        deliveryStats.averageDistance = deliveryStats.totalDistance / deliveryStats.totalDeliveries;
      }

      payments = deliveryPayments.map(payment => ({
        id: payment._id,
        type: payment.type,
        action: payment.type === 'delivery_charge' ? 'Delivery Fee Charged' : 'Commission Earned',
        amount: payment.amount,
        distance: payment.metadata?.distance || 0,
        pickupLocation: payment.metadata?.pickup_location || 'N/A',
        deliveryLocation: payment.metadata?.delivery_location || 'N/A',
        commission: payment.type === 'delivery_commission' ? payment.amount : 0,
        date: payment.createdAt,
        status: payment.status,
        description: payment.description
      }));

      paymentStats = {
        roleType: 'delivery',
        ...deliveryStats
      };
    }

    // REQUESTER - Show registration & request payments
    else if (userRoles.includes('requester')) {
      console.log('📝 Fetching requester payments...');

      const requesterPayments = await Payment.find({
        userId: userId,
        type: { $in: ['registration_fee', 'request_fee', 'delivery_charge'] }
      }).sort({ createdAt: -1 }).limit(50);

      const registrationFee = requesterPayments.find(p => p.type === 'registration_fee')?.amount || 0;
      const requestFees = requesterPayments.filter(p => p.type === 'request_fee');
      const deliveryCharges = requesterPayments.filter(p => p.type === 'delivery_charge');

      const requesterStats = {
        registrationFee: registrationFee,
        totalServiceFees: requestFees.reduce((sum, p) => sum + p.amount, 0),
        totalDeliveryCharges: deliveryCharges.reduce((sum, p) => sum + p.amount, 0),
        totalRequests: requestFees.length,
        totalPaid: requesterPayments.reduce((sum, p) => sum + p.amount, 0)
      };

      payments = requesterPayments.map(payment => ({
        id: payment._id,
        type: payment.type,
        action: payment.type === 'registration_fee' ? 'Registration Fee' :
          payment.type === 'request_fee' ? 'Request Service Fee' : 'Delivery Charge',
        amount: payment.amount,
        date: payment.createdAt,
        status: payment.status,
        description: payment.description
      }));

      paymentStats = {
        roleType: 'requester',
        ...requesterStats
      };
    }

    // DONOR - Show paid delivery payments only
    else if (userRoles.includes('donor')) {
      console.log('❤️ Fetching donor delivery payments...');

      const donorPayments = await Payment.find({
        userId: userId,
        type: 'delivery_charge'
      }).sort({ createdAt: -1 }).limit(50);

      // Get donation count from Donation model
      const Donation = require('../models/Donation');
      const totalDonations = await Donation.countDocuments({ donorId: userId });

      const donorStats = {
        totalDonations: totalDonations,
        totalDeliveryCharges: donorPayments.reduce((sum, p) => sum + p.amount, 0),
        helpedFamilies: Math.floor(totalDonations * 1.2), // Estimate families helped
        averageDeliveryFee: donorPayments.length > 0 ?
          Math.round(donorPayments.reduce((sum, p) => sum + p.amount, 0) / donorPayments.length) : 0
      };

      payments = donorPayments.map(payment => ({
        id: payment._id,
        type: payment.type,
        action: 'Paid Delivery Fee',
        amount: payment.amount,
        date: payment.createdAt,
        status: payment.status,
        description: payment.description || 'Delivery charge for donation'
      }));

      paymentStats = {
        roleType: 'donor',
        ...donorStats
      };
    }

    // VOLUNTEER - Show impact metrics (no payments)
    else if (userRoles.includes('volunteer')) {
      console.log('🤝 Fetching volunteer impact metrics...');

      // Get volunteer delivery count from assignments
      const VolunteerDelivery = require('../models/VolunteerDelivery');
      const volunteerDeliveries = await VolunteerDelivery.countDocuments({
        volunteerId: userId,
        status: 'completed'
      });

      const volunteerStats = {
        totalVolunteerHours: volunteerDeliveries * 2, // Estimate 2 hours per delivery
        totalDeliveries: volunteerDeliveries,
        helpedFamilies: volunteerDeliveries, // Each delivery helps one family
        message: volunteerDeliveries > 0 ?
          `You've completed ${volunteerDeliveries} volunteer deliveries. Thank you!` :
          'Start volunteering to help families in need!'
      };

      payments = []; // Volunteers don't have payment transactions

      paymentStats = {
        roleType: 'volunteer',
        ...volunteerStats
      };
    }

    // DEFAULT - Show registration fee only
    else {
      console.log('👤 Default user - showing registration payments only');

      const registrationPayments = await Payment.find({
        userId: userId,
        type: 'registration_fee'
      }).sort({ createdAt: -1 });

      payments = registrationPayments.map(payment => ({
        id: payment._id,
        type: payment.type,
        action: 'Registration Fee',
        amount: payment.amount,
        date: payment.createdAt,
        status: payment.status,
        description: payment.description
      }));

      paymentStats = {
        roleType: 'default',
        registrationFee: registrationPayments[0]?.amount || 0
      };
    }

    console.log(`✅ Found ${payments.length} payments for ${paymentStats.roleType} user`);

    res.json({
      success: true,
      data: {
        payments,
        stats: paymentStats,
        userRole: userRoles[0] || 'default'
      }
    });
  } catch (error) {
    console.error('❌ Error fetching role-based payments:', error);
    res.status(500).json({ message: error.message });
  }
};

// ✅ Export
module.exports = {
  getProfile,
  updateProfile,
  changePassword,
  changeEmail,
  forgotPassword,
  resetPassword,
  deleteAccount,
  refreshToken,
  logout,
  getUserActivity,
  getUserDonations,
  getUserRequests,
  getUserStatistics,
  getUserPaymentStatistics,
  getUserPayments,
  getRoleBasedUserPayments,
};
