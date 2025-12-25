const mongoose = require('mongoose');

const earningSchema = new mongoose.Schema({
  // User who earned the money
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Related delivery
  delivery: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Delivery',
    required: true
  },
  
  // Earning details
  baseAmount: {
    type: Number,
    required: true,
    default: 50 // Base earning per delivery
  },
  distanceBonus: {
    type: Number,
    default: 0
  },
  totalAmount: {
    type: Number,
    required: true
  },
  
  // Commission and deductions
  commission: {
    type: Number,
    default: 0
  },
  penalties: {
    type: Number,
    default: 0
  },
  netAmount: {
    type: Number,
    required: true
  },
  
  // Status tracking
  status: {
    type: String,
    enum: ['pending', 'completed', 'requested', 'paid'],
    default: 'pending'
  },
  
  // Payout request information
  payoutRequest: {
    status: {
      type: String,
      enum: ['none', 'requested', 'approved', 'rejected'],
      default: 'none'
    },
    requestedAt: Date,
    approvedAt: Date,
    rejectedAt: Date,
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    rejectedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    rejectionReason: String,
    transactionId: String,
    paymentMethod: {
      type: String,
      enum: ['bank_transfer', 'mobile_money', 'cash', 'paypal', 'stripe'],
      default: 'bank_transfer'
    },
    accountDetails: {
      accountNumber: String,
      bankName: String,
      accountHolderName: String,
      routingNumber: String
    }
  },
  
  // Delivery details for reference
  deliveryDetails: {
    itemType: {
      type: String,
      enum: ['Donation', 'Request']
    },
    distance: Number,
    pickupAddress: String,
    deliveryAddress: String,
    completedAt: Date
  },
  
  // Admin processing
  processedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  processingNotes: String,
  
  // Timestamps
  earnedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
earningSchema.index({ user: 1, status: 1 });
earningSchema.index({ 'payoutRequest.status': 1 });
earningSchema.index({ status: 1, createdAt: -1 });
earningSchema.index({ delivery: 1 });

// Calculate net amount before saving
earningSchema.pre('save', function(next) {
  this.netAmount = this.totalAmount - this.commission - this.penalties;
  next();
});

module.exports = mongoose.model('Earning', earningSchema);
