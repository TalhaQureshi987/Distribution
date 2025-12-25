const User = require('../models/User');

// Middleware to check if user is verified for actions
const requireVerification = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check if user has completed identity verification
    if (!user.emailVerified) {
      return res.status(403).json({ 
        message: 'Email verification required',
        verificationRequired: true,
        verificationType: 'email'
      });
    }

    if (user.verificationStatus !== 'verified') {
      return res.status(403).json({ 
        message: 'Identity verification required to perform this action',
        verificationRequired: true,
        verificationType: 'identity',
        verificationStatus: user.verificationStatus || 'pending'
      });
    }

    next();
  } catch (error) {
    console.error('Verification middleware error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Optional verification check (returns status but doesn't block)
const checkVerificationStatus = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);
    
    if (user) {
      req.verificationStatus = {
        emailVerified: user.emailVerified || false,
        identityVerified: user.verificationStatus === 'verified',
        verificationStatus: user.verificationStatus || 'pending'
      };
    }
    
    next();
  } catch (error) {
    console.error('Verification status check error:', error);
    next(); // Continue even if check fails
  }
};

module.exports = {
  requireVerification,
  checkVerificationStatus
};
