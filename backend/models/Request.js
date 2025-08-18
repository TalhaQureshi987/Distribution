const mongoose = require("mongoose");

const RequestSchema = new mongoose.Schema(
  {
    requesterId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    requesterName: { type: String, required: true },
    title: { type: String, required: true },
    description: { type: String, required: true },
    foodType: { type: String, required: true },
    quantity: { type: Number, required: true, min: 1 },
    quantityUnit: { type: String, required: true },
    neededBy: { type: Date, required: true },
    pickupAddress: { type: String, required: true },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: { type: [Number], default: undefined }, // [lng, lat]
    },
    notes: { type: String },
    isUrgent: { type: Boolean, default: false },
    images: [{ type: String }],
    status: {
      type: String,
      enum: ["pending", "approved", "fulfilled", "cancelled", "expired"],
      default: "pending",
    },
    fulfilledBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    fulfilledAt: { type: Date },
    reason: { type: String },
  },
  { timestamps: true }
);

// Pre-save to set GeoJSON coordinates
RequestSchema.pre("save", function (next) {
  if (this.longitude != null && this.latitude != null) {
    this.location = {
      type: "Point",
      coordinates: [this.longitude, this.latitude],
    };
  }
  next();
});

RequestSchema.index({ location: "2dsphere" });

module.exports = mongoose.model("Request", RequestSchema);
