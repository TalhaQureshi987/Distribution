const mongoose = require("mongoose");

const DonationSchema = new mongoose.Schema(
  {
    donorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    donorName: { type: String, required: true },
    title: { type: String, required: true },
    description: {
      type: String,
      required: [true, "Description is required"],
      minlength: [10, "Description must be at least 10 characters"],
      maxlength: [2000, "Description cannot exceed 2000 characters"],
      trim: true,
      validate: {
        validator: function (v) {
          return v && v.trim().length > 0;
        },
        message: "Description cannot be empty",
      },
    },

    // Enhanced food information
    foodType: {
      type: String,
      required: true,
      enum: ["Food", "Clothes", "Medicine", "Other"],
    },
    foodCategory: {
      type: String,
      required: function () {
        return this.foodType === "Food";
      }, // Only required for Food category
      enum: [
        "Cereals & Grains",
        "Rice & Flour",
        "Spices & Seasonings",
        "Fruits & Vegetables",
        "Dairy Products",
        "Meat & Poultry",
        "Seafood",
        "Bakery Items",
        "Beverages",
        "Prepared Meals",
        "Snacks & Sweets",
        "Cooking Oil & Ghee",
        "Pulses & Lentils",
        "Dry Fruits & Nuts",
        "Other Food Items",
      ],
    },
    foodName: {
      type: String,
      required: function () {
        return this.foodType === "Food";
      }, // Only required for Food category
      trim: true,
      maxlength: [100, "Food name cannot exceed 100 characters"],
    },
    quantity: { type: Number, required: true, min: 1 },
    quantityUnit: { type: String, required: true },
    expiryDate: { type: Date, required: true },
    pickupAddress: { type: String, required: true },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    // Optional GeoJSON point for geospatial queries (if you enable)
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: { type: [Number], default: undefined }, // [lng, lat]
    },
    notes: { type: String },
    isUrgent: { type: Boolean, default: false },
    images: [{ type: String }],
    deliveryOption: {
      type: String,
      enum: [
        "Self delivery",
        "Volunteer Delivery",
        "Paid Delivery",
        "Paid Delivery (Earn)",
      ],
      required: true,
    },

    // Payment information
    paymentAmount: { type: Number, min: 0 },
    paymentStatus: {
      type: String,
      enum: ["pending", "completed", "failed", "refunded"],
      default: "pending",
    },
    stripePaymentIntentId: { type: String },
    paidAt: { type: Date },

    status: {
      type: String,
      enum: [
        "available",
        "reserved",
        "assigned",
        "picked_up",
        "in_transit",
        "completed",
        "expired",
        "cancelled",
      ],
      default: "available",
    },

    // Assignment tracking for volunteer/delivery integration
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User", // volunteer or delivery person
    },
    assignedAt: { type: Date },
    assignmentType: {
      type: String,
      enum: ["volunteer", "delivery", "self"],
      default: "self",
    },

    // Delivery pricing fields
    deliveryDistance: { type: Number, min: 0 }, // Distance in kilometers
    totalDeliveryPrice: { type: Number, min: 0 }, // Full price based on distance
    deliveryCommission: { type: Number, min: 0 }, // 10% commission for platform
    deliveryPayment: { type: Number, min: 0 }, // 90% payment for delivery person

    // Completion tracking
    completedAt: { type: Date },
    completedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User", // Care Connect team member or admin
    },
    completionNotes: { type: String },

    // Admin verification fields
    verificationStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },
    verifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    verifiedAt: { type: Date },
    verificationNotes: { type: String },

    reservedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    reservedAt: { type: Date },
  },
  { timestamps: true }
);

// Pre-save hook to set GeoJSON coordinates
DonationSchema.pre("save", function (next) {
  if (this.longitude != null && this.latitude != null) {
    this.location = {
      type: "Point",
      coordinates: [this.longitude, this.latitude],
    };
  }
  next();
});

DonationSchema.index({ location: "2dsphere" });

const Donation = mongoose.model("Donation", DonationSchema);

// Register alias for lowercase "donation" to handle refPath compatibility
mongoose.model("donation", DonationSchema);

module.exports = Donation;
