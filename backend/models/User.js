// models/User.js
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs'); // pick bcryptjs everywhere for consistency

const phoneRegex = /^\+?\d{7,15}$/;

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },

  email: { 
    type: String, 
    required: true, 
    unique: true, 
    lowercase: true, 
    trim: true 
  },

  phone: { 
    type: String, 
    trim: true,
    validate: {
      validator: v => !v || phoneRegex.test(v),
      message: props => `${props.value} is not a valid phone number!`
    },
    unique: true,
    sparse: true
  },

  address: { type: String },
  profileImage: { type: String, default: null },

  // CNIC & identity verification
  cnicNumber: { 
    type: String, 
    unique: true,
    sparse: true,
    validate: {
      validator: v => !v || /^\d{13}$/.test(v),
      message: 'CNIC must be exactly 13 digits'
    }
  },
  cnicFrontPhoto: { type: String },
  cnicBackPhoto: { type: String },
  selfiePhoto: { type: String },

  identityVerificationStatus: {
    type: String,
    enum: ['not_submitted', 'pending', 'approved', 'rejected'],
    default: 'not_submitted'
  },
  identityRejectionReason: { type: String },

  // Email verification
  isEmailVerified: { type: Boolean, default: false },
  emailVerificationCode: { type: String },
  emailCodeExpiry: { type: Date },
  
  // Email OTP verification
  emailOTP: { type: Number },
  emailOTPExpires: { type: Date },

  // Payment
  paymentStatus: {
    type: String,
    enum: ['not_required', 'pending', 'paid', 'failed','free'],
    default: 'not_required'
  },
  applicationFeePaid: { type: Boolean, default: false },
  paymentAmount: { type: Number, default: 0 }, // Amount paid in PKR
  paymentCurrency: { type: String, default: 'PKR' }, // Currency type

  // Stripe
  stripeCustomerId: { type: String },
  defaultPaymentMethodId: { type: String },

  // Roles & status
  role: { 
    type: String, 
    enum: ['donor', 'requester', 'volunteer', 'delivery', 'admin'], 
    required: true 
  },
  status: {
    type: String,
    enum: ['pending', 'email_verified', 'approved', 'rejected'],
    default: 'pending'
  },

  // Password
  password: { type: String, required: true },

  // Audit
  approvedAt: { type: Date },
  rejectionReason: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// Update timestamp & hash password
UserSchema.pre('save', async function(next) {
  this.updatedAt = new Date();
  if (!this.isModified('password')) return next();

  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err);
  }
});

// Compare password
UserSchema.methods.comparePassword = function(plain) {
  return bcrypt.compare(plain, this.password);
};

module.exports = mongoose.model('User', UserSchema);
