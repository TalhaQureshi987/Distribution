// Role-based access control middleware
const User = require('../models/User');

// Check if user is approved and has required role (for actions - no identity verification required)
const requireApprovedRole = (allowedRoles) => {
  return async (req, res, next) => {
    try {
      const userId = req.user._id;
      const user = await User.findById(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      // Check if user status is approved
      if (user.status !== 'approved') {
        return res.status(403).json({
          success: false,
          message: 'Account pending admin approval. You cannot perform this action until your account is approved.',
          userStatus: user.status,
          requiresApproval: true
        });
      }

      // Check if user has required role
      if (!allowedRoles.includes(user.role)) {
        return res.status(403).json({
          success: false,
          message: `Access denied. This action requires one of these roles: ${allowedRoles.join(', ')}. Your role: ${user.role}`,
          userRole: user.role,
          requiredRoles: allowedRoles
        });
      }

      // Add user info to request for use in controllers
      req.approvedUser = {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status,
        identityVerificationStatus: user.identityVerificationStatus
      };

      next();
    } catch (error) {
      console.error('Role middleware error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error during authorization check'
      });
    }
  };
};

// Check if user is approved, has required role AND identity verified (for registration)
const requireApprovedRoleWithVerification = (allowedRoles) => {
  return async (req, res, next) => {
    try {
      const userId = req.user._id;
      const user = await User.findById(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      // Check if user status is approved
      if (user.status !== 'approved') {
        return res.status(403).json({
          success: false,
          message: 'Account pending admin approval. You cannot perform this action until your account is approved.',
          userStatus: user.status,
          requiresApproval: true
        });
      }

      // Check if user has required role
      if (!allowedRoles.includes(user.role)) {
        return res.status(403).json({
          success: false,
          message: `Access denied. This action requires one of these roles: ${allowedRoles.join(', ')}. Your role: ${user.role}`,
          userRole: user.role,
          requiredRoles: allowedRoles
        });
      }

      // Check identity verification for registration
      if (user.identityVerificationStatus !== 'approved') {
        return res.status(403).json({
          success: false,
          message: 'Identity verification required. Please complete identity verification before registering for this service.',
          identityStatus: user.identityVerificationStatus,
          requiresIdentityVerification: true
        });
      }

      // Add user info to request for use in controllers
      req.approvedUser = {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status,
        identityVerificationStatus: user.identityVerificationStatus
      };

      next();
    } catch (error) {
      console.error('Role middleware error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error during authorization check'
      });
    }
  };
};

// Specific role middlewares
const requireDonor = requireApprovedRole(['donor']);
const requireRequester = requireApprovedRole(['requester']);
const requireVolunteer = requireApprovedRole(['volunteer']);
const requireDelivery = requireApprovedRole(['delivery']);
const requireDonorOrVolunteer = requireApprovedRole(['donor', 'volunteer']);
const requireRequesterOrVolunteer = requireApprovedRole(['requester', 'volunteer']);
const admin = requireApprovedRole(['admin']);

// Specific role middlewares with identity verification
const requireDonorWithVerification = requireApprovedRoleWithVerification(['donor']);
const requireRequesterWithVerification = requireApprovedRoleWithVerification(['requester']);
const requireVolunteerWithVerification = requireApprovedRoleWithVerification(['volunteer']);
const requireDeliveryWithVerification = requireApprovedRoleWithVerification(['delivery']);
const requireDonorOrVolunteerWithVerification = requireApprovedRoleWithVerification(['donor', 'volunteer']);
const requireRequesterOrVolunteerWithVerification = requireApprovedRoleWithVerification(['requester', 'volunteer']);

// Check user status without role restriction (for profile access, etc.)
const requireApprovedStatus = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    if (user.status !== 'approved') {
      return res.status(403).json({
        success: false,
        message: 'Account pending admin approval.',
        userStatus: user.status,
        requiresApproval: true
      });
    }

    req.approvedUser = {
      _id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      status: user.status,
      identityVerificationStatus: user.identityVerificationStatus
    };

    next();
  } catch (error) {
    console.error('Status middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during status check'
    });
  }
};

module.exports = {
  requireApprovedRole,
  requireDonor,
  requireRequester,
  requireVolunteer,
  requireDelivery,
  requireDonorOrVolunteer,
  requireRequesterOrVolunteer,
  admin,
  requireApprovedStatus,
  requireApprovedRoleWithVerification,
  requireDonorWithVerification,
  requireRequesterWithVerification,
  requireVolunteerWithVerification,
  requireDeliveryWithVerification,
  requireDonorOrVolunteerWithVerification,
  requireRequesterOrVolunteerWithVerification
};
