const mongoose = require('mongoose');

const IdentityVerificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  
  // Email verification
  emailVerified: { type: Boolean, default: false },
  emailVerificationCode: { type: String },
  emailVerificationExpires: { type: Date },
  emailVerifiedAt: { type: Date },
  
  // Identity documents
  cnicFrontImage: { type: String }, // URL to CNIC front image
  cnicBackImage: { type: String },  // URL to CNIC back image
  selfieImage: { type: String },    // URL to selfie image
  
  // Verification status
  identityStatus: {
    type: String,
    enum: ['pending_email', 'email_verified', 'documents_uploaded', 'under_review', 'verified', 'rejected'],
    default: 'pending_email'
  },
  
  // Admin review
  reviewedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  reviewedAt: { type: Date },
  rejectionReason: { type: String },
  adminNotes: { type: String },
  
  // Extracted CNIC data (for validation)
  extractedCnicNumber: { type: String },
  extractedName: { type: String },
  extractedDateOfBirth: { type: Date },
  
  // Verification attempts
  verificationAttempts: { type: Number, default: 0 },
  lastAttemptAt: { type: Date },
  
  // Metadata
  ipAddress: { type: String },
  userAgent: { type: String },
  
}, { timestamps: true });

// Indexes for performance
IdentityVerificationSchema.index({ userId: 1 });
IdentityVerificationSchema.index({ identityStatus: 1 });
IdentityVerificationSchema.index({ createdAt: -1 });

// Methods
IdentityVerificationSchema.methods.canAttemptVerification = function() {
  const maxAttempts = 10; 
  const cooldownPeriod = 1 * 60 * 60 * 1000; 
  
  if (this.verificationAttempts >= maxAttempts) {
    const timeSinceLastAttempt = Date.now() - this.lastAttemptAt.getTime();
    return timeSinceLastAttempt > cooldownPeriod;
  }
  
  return true;
};

IdentityVerificationSchema.methods.incrementAttempt = function() {
  this.verificationAttempts += 1;
  this.lastAttemptAt = new Date();
};

module.exports = mongoose.model('IdentityVerification', IdentityVerificationSchema);
