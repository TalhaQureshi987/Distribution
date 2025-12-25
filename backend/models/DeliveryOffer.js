const mongoose = require('mongoose');

const deliveryOfferSchema = new mongoose.Schema({
  // Reference to the original donation or request
  itemId: {
    type: mongoose.Schema.Types.ObjectId,
    refPath: 'itemType',
    required: true
  },
  itemType: {
    type: String,
    required: true,
    enum: ['donation', 'request']
  },
  
  // The owner of the item (donor or requester)
  ownerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // The delivery person who made the offer
  deliveryPersonId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Offer details
  estimatedEarning: {
    type: Number,
    required: true
  },
  message: {
    type: String,
    default: 'I would like to help with this delivery.'
  },
  
  // Status tracking
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'expired'],
    default: 'pending'
  },
  
  // Timing
  offeredAt: {
    type: Date,
    default: Date.now
  },
  approvedAt: Date,
  rejectedAt: Date,
  
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours from now
  },
  
  // Final delivery assignment (created after approval)
  deliveryId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Delivery'
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
deliveryOfferSchema.index({ ownerId: 1, status: 1, createdAt: -1 });
deliveryOfferSchema.index({ deliveryPersonId: 1, status: 1 });
deliveryOfferSchema.index({ itemId: 1, itemType: 1 });

// Auto-expire offers after 24 hours
deliveryOfferSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('DeliveryOffer', deliveryOfferSchema);
