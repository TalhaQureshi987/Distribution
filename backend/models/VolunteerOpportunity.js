const mongoose = require("mongoose");

const volunteerOpportunitySchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
    },
    organizerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    organizerName: {
      type: String,
      required: true,
    },
    requiredSkills: [{
      type: String,
      trim: true,
    }],
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    address: {
      type: String,
      trim: true,
    },
    location: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point",
      },
      coordinates: {
        type: [Number],
        default: [0, 0],
      },
    },
    maxVolunteers: {
      type: Number,
      default: 10,
      min: 1,
    },
    currentVolunteers: {
      type: Number,
      default: 0,
      min: 0,
    },
    volunteers: [{
      userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
      userName: String,
      appliedAt: {
        type: Date,
        default: Date.now,
      },
      status: {
        type: String,
        enum: ["pending", "approved", "rejected"],
        default: "pending",
      },
    }],
    status: {
      type: String,
      enum: ["open", "closed", "cancelled", "completed"],
      default: "open",
    },
    priority: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "medium",
    },
    category: {
      type: String,
      enum: ["Food", "Hygiene", "Education", "Medical", "General"],
      default: "General",
    },
  },
  {
    timestamps: true,
  }
);

// Index for geospatial queries
volunteerOpportunitySchema.index({ location: "2dsphere" });

// Index for text search
volunteerOpportunitySchema.index({ title: "text", description: "text" });

module.exports = mongoose.model("VolunteerOpportunity", volunteerOpportunitySchema);
