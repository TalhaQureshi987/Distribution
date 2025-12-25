const mongoose = require('mongoose');

const volunteerAssignmentSchema = new mongoose.Schema({
  // Reference to donation or request
  donationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Donation',
    default: null
  },
  requestId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Request',
    default: null
  },
  
  // The volunteer assigned
  volunteerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Assignment status
  status: {
    type: String,
    enum: ['assigned', 'in_progress', 'completed', 'cancelled'],
    default: 'assigned'
  },
  
  // Timing
  assignedAt: {
    type: Date,
    default: Date.now
  },
  startedAt: Date,
  completedAt: Date,
  
  // Notes and feedback
  notes: String,
  feedback: {
    rating: {
      type: Number,
      min: 1,
      max: 5
    },
    comment: String,
    submittedAt: Date
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
volunteerAssignmentSchema.index({ volunteerId: 1, status: 1 });
volunteerAssignmentSchema.index({ donationId: 1 });
volunteerAssignmentSchema.index({ requestId: 1 });
volunteerAssignmentSchema.index({ assignedAt: -1 });

module.exports = mongoose.model('VolunteerAssignment', volunteerAssignmentSchema);
