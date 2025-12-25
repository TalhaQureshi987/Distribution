const mongoose = require("mongoose");

const activitySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    type: {
      type: String,
      required: true,
      enum: [
        "registration",
        "login",
        "logout",
        "email_verification",
        "payment",
        "profile_update",
        "role_change",
        "status_change",
        "donation_created",
        "donation_updated",
        "donation_verified",
        "donation_verification_approved",
        "donation_rejected",
        "request_created",
        "request_updated",
        "volunteer_activity",
        "delivery_activity",
        "admin_action",
        "password_change",
        "account_deletion",
        "identity_verification_submitted",
        "identity_verification_approved",
        "identity_verification_rejected",
      ],
    },
    description: {
      type: String,
      required: true,
    },
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    ipAddress: {
      type: String,
    },
    userAgent: {
      type: String,
    },
    location: {
      type: String,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  {
    timestamps: true,
  }
);

// Index for efficient queries
activitySchema.index({ userId: 1, createdAt: -1 });
activitySchema.index({ type: 1, createdAt: -1 });
activitySchema.index({ createdAt: -1 });

// Static method to log activity
activitySchema.statics.logActivity = async function (
  userId,
  type,
  description,
  details = {},
  req = null
) {
  try {
    const activityData = {
      userId,
      type,
      description,
      details,
    };

    if (req) {
      activityData.ipAddress = req.ip || req.connection.remoteAddress;
      activityData.userAgent = req.get("User-Agent");
    }

    const activity = new this(activityData);
    await activity.save();
    return activity;
  } catch (error) {
    console.error("Error logging activity:", error);
  }
};

module.exports = mongoose.model("Activity", activitySchema);
