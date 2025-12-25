const mongoose = require("mongoose");

const NotificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    title: { type: String, required: true },
    message: { type: String, required: true },
    type: {
      type: String,
      enum: [
        "donation", 
        "request", 
        "message", 
        "volunteer", 
        "volunteer_offer",
        "volunteer_approved",
        "volunteer_rejected",
        "delivery_offer",
        "delivery_approved",
        "system", 
        "approval", 
        "rejection",
        "identity_verification",
        "delivery_assigned",
        "delivery_update",
        "earning_added",
        "payout_request",
        "delivery_available"
      ],
      required: true,
    },
    isRead: { type: Boolean, default: false },
    readAt: { type: Date },
    data: {
      donationId: { type: mongoose.Schema.Types.ObjectId, ref: "Donation" },
      requestId: { type: mongoose.Schema.Types.ObjectId, ref: "Request" },
      chatRoomId: { type: mongoose.Schema.Types.ObjectId, ref: "ChatRoom" },
      volunteerId: { type: mongoose.Schema.Types.ObjectId, ref: "Volunteer" },
    },
    priority: {
      type: String,
      enum: ["low", "medium", "high", "urgent"],
      default: "medium",
    },
  },
  { timestamps: true }
);

NotificationSchema.index({ userId: 1, createdAt: -1 });
NotificationSchema.index({ userId: 1, isRead: 1 });

module.exports = mongoose.model("Notification", NotificationSchema);
