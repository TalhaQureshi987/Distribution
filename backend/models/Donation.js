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
      required: [true, 'Description is required'],
      minlength: [10, 'Description must be at least 10 characters'],
      maxlength: [2000, 'Description cannot exceed 2000 characters'],
      trim: true,
      validate: {
        validator: function(v) {
          return v && v.trim().length > 0;
        },
        message: 'Description cannot be empty'
      }
    },    foodType: { type: String, required: true },
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
    status: {
      type: String,
      enum: ["available", "reserved", "picked_up", "expired", "cancelled"],
      default: "available",
    },
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

module.exports = mongoose.model("Donation", DonationSchema);
