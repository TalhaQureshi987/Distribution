const mongoose = require("mongoose");

const requestSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    requestType: {
      type: String,
      required: true,
      enum: [
        "food_request",
        "volunteer_application",
        "partnership_request",
        "feedback_report",
        "account_verification",
        "other",
      ],
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    priority: {
      type: String,
      enum: ["low", "medium", "high", "urgent"],
      default: "medium",
    },
    status: {
      type: String,
      enum: [
        "pending_verification",
        "approved",
        "rejected",
        "in_progress",
        "completed",
      ],
      default: "pending_verification",
    },
    verificationStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },
    verificationNotes: {
      type: String,
      trim: true,
    },
    rejectionReason: {
      type: String,
      trim: true,
    },
    verifiedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    verificationDate: {
      type: Date,
    },
    attachments: [
      {
        filename: String,
        url: String,
        uploadDate: {
          type: Date,
          default: Date.now,
        },
      },
    ],
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    contactInfo: {
      phone: String,
      email: String,
      address: String,
    },
  },
  {
    timestamps: true,
  }
);

// Index for efficient queries
requestSchema.index({ status: 1, verificationStatus: 1 });
requestSchema.index({ userId: 1, createdAt: -1 });
requestSchema.index({ requestType: 1, priority: 1 });

// Validation for delivery options in metadata
requestSchema.pre("save", function (next) {
  if (this.metadata && this.metadata.deliveryOption) {
    const validDeliveryOptions = [
      "Self delivery",
      "Volunteer Delivery",
      "Paid Delivery",
      "Paid Delivery (Earn)",
    ];
    if (!validDeliveryOptions.includes(this.metadata.deliveryOption)) {
      const error = new Error(
        `Invalid delivery option: ${
          this.metadata.deliveryOption
        }. Must be one of: ${validDeliveryOptions.join(", ")}`
      );
      return next(error);
    }
  }
  next();
});

const Request = mongoose.model("Request", requestSchema);

// Register alias for lowercase "request" to handle refPath compatibility
mongoose.model("request", requestSchema);

module.exports = Request;
