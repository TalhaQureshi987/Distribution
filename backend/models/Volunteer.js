const mongoose = require("mongoose");

const VolunteerSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    userName: { type: String, required: true },
    email: { type: String, required: true },
    phone: { type: String },
    skills: [{ type: String }],
    availability: {
      days: [{ type: String, enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] }],
      hours: {
        start: { type: String },
        end: { type: String },
      },
    },
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: { type: [Number], default: undefined }, // [lng, lat]
    },
    address: { type: String },
    status: {
      type: String,
      enum: ["active", "inactive", "pending"],
      default: "pending",
    },
    totalHours: { type: Number, default: 0 },
    completedTasks: { type: Number, default: 0 },
    rating: { type: Number, default: 0 },
    reviews: [{ type: Number }], // Array of review ratings
  },
  { timestamps: true }
);

VolunteerSchema.index({ location: "2dsphere" });

module.exports = mongoose.model("Volunteer", VolunteerSchema);
