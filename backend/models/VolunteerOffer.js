const mongoose = require("mongoose");

const volunteerOfferSchema = new mongoose.Schema(
  {
    // Reference to the original donation or request
    itemId: {
      type: mongoose.Schema.Types.ObjectId,
      refPath: "itemType",
      required: true,
    },
    itemType: {
      type: String,
      required: true,
      enum: ["donation", "request"],
    },

    // The owner of the item (donor or requester)
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // The volunteer who made the offer
    volunteerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // Offer details
    message: {
      type: String,
      default: "I would like to help with this volunteer opportunity.",
    },

    // Status tracking
    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "expired", "completed"],
      default: "pending",
    },

    // Timing
    offeredAt: {
      type: Date,
      default: Date.now,
    },
    approvedAt: Date,
    rejectedAt: Date,
    completedAt: Date,
    rejectionReason: {
      type: String,
      maxlength: 500,
    },

    expiresAt: {
      type: Date,
      default: () => new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours from now
    },

    // Final volunteer assignment (created after approval)
    assignmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "VolunteerAssignment",
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for efficient queries
volunteerOfferSchema.index({ ownerId: 1, status: 1, createdAt: -1 });
volunteerOfferSchema.index({ volunteerId: 1, status: 1 });
volunteerOfferSchema.index({ itemId: 1, itemType: 1 });

// Auto-expire offers after 24 hours
volunteerOfferSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model("VolunteerOffer", volunteerOfferSchema);
