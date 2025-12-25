const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  type: {
    type: String,
    enum: [
      'registration_fee',
      'request_fee', 
      'delivery_charge',
      'delivery_commission',
      'donation', 
      'request', 
      'payout'
    ],
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  currency: {
    type: String,
    default: 'PKR'
  },
  status: {
    type: String,
    enum: ['pending', 'completed', 'failed', 'refunded'],
    default: 'pending'
  },
  description: {
    type: String,
    required: true
  },
  // Reference to related entities
  deliveryId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Delivery',
    required: false
  },
  requestId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Request',
    required: false
  },
  donationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Donation',
    required: false
  },
  // Payment gateway information
  paymentGateway: {
    type: String,
    enum: ['stripe', 'paypal', 'jazzcash', 'easypaisa', 'bank_transfer'],
    required: false
  },
  transactionId: {
    type: String,
    required: false
  },
  gatewayResponse: {
    type: mongoose.Schema.Types.Mixed,
    required: false
  },
  // Additional metadata
  metadata: {
    distance: Number,
    commission_rate: Number,
    pickup_location: String,
    delivery_location: String
  },
  processedAt: {
    type: Date,
    required: false
  },
  failureReason: {
    type: String,
    required: false
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
paymentSchema.index({ userId: 1, type: 1, status: 1 });
paymentSchema.index({ createdAt: -1 });
paymentSchema.index({ type: 1, status: 1 });
paymentSchema.index({ transactionId: 1 });

// Static method to create request fee payment (100 PKR)
paymentSchema.statics.createRequestFeePayment = function(userId, requestId) {
  return this.create({
    userId: userId,
    type: 'request_fee',
    amount: 100, // Fixed 100 PKR for each request
    currency: 'PKR',
    status: 'completed',
    description: 'Request submission fee',
    requestId: requestId
  });
};

// Static method to create registration fee payment
paymentSchema.statics.createRegistrationFeePayment = function(userId, amount = 50) {
  return this.create({
    userId: userId,
    type: 'registration_fee',
    amount: amount,
    currency: 'PKR',
    status: 'completed',
    description: 'User registration fee'
  });
};

// Static method to create delivery payment
paymentSchema.statics.createDeliveryPayment = function(userId, deliveryId, amount, distance, pickupLocation, deliveryLocation) {
  return this.create({
    userId: userId,
    type: 'delivery_charge',
    amount: amount,
    currency: 'PKR',
    status: 'completed',
    description: `Delivery charge for ${distance}km delivery`,
    deliveryId: deliveryId,
    metadata: {
      distance: distance,
      pickup_location: pickupLocation,
      delivery_location: deliveryLocation
    }
  });
};

// Static method to create delivery commission payment
paymentSchema.statics.createDeliveryCommission = function(userId, deliveryId, amount, commissionRate) {
  return this.create({
    userId: userId,
    type: 'delivery_commission',
    amount: amount,
    currency: 'PKR',
    status: 'completed',
    description: `Delivery commission (${commissionRate}%)`,
    deliveryId: deliveryId,
    metadata: {
      commission_rate: commissionRate
    }
  });
};

module.exports = mongoose.model('Payment', paymentSchema);
