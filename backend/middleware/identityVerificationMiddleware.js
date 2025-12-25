const User = require('../models/User');

// Middleware to check if user has verified their identity (CNIC)
// This is required for role-based actions (donate, request, deliver, volunteer)
const requireIdentityVerification = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    // Check if user has verified their identity
    if (!user.isIdentityVerified) {
      return res.status(403).json({ 
        success: false,
        message: 'Identity verification required to perform this action',
        requiresIdentityVerification: true,
        identityVerificationStatus: user.identityVerificationStatus,
        redirectTo: '/identity-verification'
      });
    }

    // Check if identity verification is still pending
    if (user.identityVerificationStatus === 'pending') {
      return res.status(403).json({ 
        success: false,
        message: 'Your identity verification is under review. Please wait for admin approval.',
        identityVerificationStatus: 'pending',
        redirectTo: '/identity-verification-status'
      });
    }

    // Check if identity verification was rejected
    if (user.identityVerificationStatus === 'rejected') {
      return res.status(403).json({ 
        success: false,
        message: 'Your identity verification was rejected. Please resubmit with correct information.',
        identityVerificationStatus: 'rejected',
        rejectionReason: user.identityRejectionReason,
        redirectTo: '/identity-verification'
      });
    }

    // User is verified, proceed
    next();
  } catch (error) {
    console.error('Identity verification middleware error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error checking identity verification' 
    });
  }
};

// Middleware to check if user has paid (for paid roles)
const requirePayment = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    // Check if user has paid (if payment is required for their role)
    if ((user.role === 'requester' || user.role === 'delivery') && !user.hasPaid) {
      return res.status(402).json({
        success: false,
        message: 'Payment required to perform this action',
        requiresPayment: true,
        redirectTo: '/payment'
      });
    }

    next();
  } catch (error) {
    console.error('Payment verification middleware error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error checking payment status' 
    });
  }
};

// Combined middleware for role-based actions
const requireRoleActionAccess = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    // Check email verification first
    if (!user.isEmailVerified) {
      return res.status(403).json({ 
        success: false,
        message: 'Email verification required',
        requiresEmailVerification: true,
        redirectTo: '/email-verification'
      });
    }

    // Check payment for paid roles
    const paidRoles = ['requester', 'delivery'];
    const userRole = user.role;
    
    if (paidRoles.includes(userRole) && !user.hasPaid) {
      return res.status(402).json({ 
        success: false,
        message: 'Payment required to perform this action',
        requiresPayment: true,
        redirectTo: '/payment'
      });
    }

    // Check identity verification
    if (!user.isIdentityVerified) {
      return res.status(403).json({ 
        success: false,
        message: 'Identity verification required to perform this action',
        requiresIdentityVerification: true,
        identityVerificationStatus: user.identityVerificationStatus,
        redirectTo: '/identity-verification'
      });
    }

    // Check if identity verification is still pending
    if (user.identityVerificationStatus === 'pending') {
      return res.status(403).json({ 
        success: false,
        message: 'Your identity verification is under review. Please wait for admin approval.',
        identityVerificationStatus: 'pending',
        redirectTo: '/identity-verification-status'
      });
    }

    // Check if identity verification was rejected
    if (user.identityVerificationStatus === 'rejected') {
      return res.status(403).json({ 
        success: false,
        message: 'Your identity verification was rejected. Please resubmit with correct information.',
        identityVerificationStatus: 'rejected',
        rejectionReason: user.identityRejectionReason,
        redirectTo: '/identity-verification'
      });
    }

    // All checks passed, proceed
    next();
  } catch (error) {
    console.error('Role action access middleware error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error checking access permissions' 
    });
  }
};

module.exports = {
  requireIdentityVerification,
  requirePayment,
  requireRoleActionAccess
};