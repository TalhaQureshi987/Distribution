const mongoose = require('mongoose');

const deliverySchema = new mongoose.Schema({
  // Core delivery information
  itemId: {
    type: mongoose.Schema.Types.ObjectId,
    refPath: 'itemType',
    required: true
  },
  itemType: {
    type: String,
    required: true,
    enum: ['Donation', 'Request']
  },
  
  // Parties involved
  deliveryPerson: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  donor: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  requester: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  
  // Delivery details
  deliveryType: {
    type: String,
    enum: ['volunteer', 'paid', 'self'],
    default: 'paid'
  },
  
  // Location information
  pickupLocation: {
    address: { type: String, required: true },
    coordinates: {
      type: [Number] // [longitude, latitude]
    }
  },
  deliveryLocation: {
    address: { type: String, required: true },
    coordinates: {
      type: [Number] // [longitude, latitude]
    }
  },
  
  // Status tracking
  status: {
    type: String,
    enum: ['pending', 'assigned', 'accepted', 'picked_up', 'in_transit', 'delivered', 'completed', 'cancelled'],
    default: 'pending'
  },
  
  // Timing
  scheduledPickupTime: Date,
  scheduledDeliveryTime: Date,
  actualPickupTime: Date,
  actualDeliveryTime: Date,
  assignedAt: Date,
  completedAt: Date,
  cancelledAt: Date,
  
  // Delivery specifics
  items: [{
    name: String,
    quantity: Number,
    unit: String
  }],
  specialInstructions: String,
  contactInfo: {
    donorPhone: String,
    requesterPhone: String,
    deliveryPersonPhone: String
  },
  
  // Distance and earnings
  estimatedDistance: Number, // in kilometers
  actualDistance: Number,
  totalEarning: {
    type: Number,
    default: 0
  },
  
  // Company commission tracking
  companyCommission: {
    amount: {
      type: Number,
      default: 0
    },
    rate: {
      type: Number,
      default: 0.15 // 15% commission rate
    },
    appliedAt: {
      type: Date,
      default: Date.now
    },
    settingsVersion: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CommissionSettings'
    }
  },
  
  // Net amount for delivery person after commission
  netEarning: {
    type: Number,
    default: 0
  },
  
  // Verification
  deliveryVerification: {
    photos: [String],
    signature: String,
    notes: String,
    verifiedAt: Date
  },
  
  // Cancellation
  cancelledBy: {
    type: String,
    enum: ['donor', 'requester', 'delivery_person', 'admin']
  },
  cancellationReason: String,
  
  // Admin notes
  adminNotes: String
}, {
  timestamps: true
});

// Indexes for efficient queries
deliverySchema.index({ status: 1, createdAt: -1 });
deliverySchema.index({ deliveryPerson: 1, status: 1 });
deliverySchema.index({ 'pickupLocation.coordinates': '2dsphere' });
deliverySchema.index({ 'deliveryLocation.coordinates': '2dsphere' });

module.exports = mongoose.model('Delivery', deliverySchema);
