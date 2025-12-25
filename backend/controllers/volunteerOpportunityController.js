const VolunteerOpportunity = require("../models/VolunteerOpportunity");
const User = require("../models/User");
const { validatePaymentRequired, calculatePaymentAmount, PAYMENT_CONFIG } = require('../middleware/paymentMiddleware');
const { logger } = require('../utils/logger');

// @desc    Create volunteer opportunity
// @route   POST /api/volunteer-opportunities
// @access  Private
const createVolunteerOpportunity = async (req, res) => {
  try {
    const {
      title,
      description,
      requiredSkills,
      startDate,
      endDate,
      address,
      latitude,
      longitude,
      maxVolunteers,
      priority,
      category,
    } = req.body;

    const opportunity = new VolunteerOpportunity({
      title,
      description,
      organizerId: req.user.id,
      organizerName: req.user.name,
      requiredSkills: requiredSkills || [],
      startDate,
      endDate,
      address,
      location: {
        type: "Point",
        coordinates: [longitude || 0, latitude || 0],
      },
      maxVolunteers: maxVolunteers || 10,
      priority: priority || "medium",
      category: category || "General",
    });

    const savedOpportunity = await opportunity.save();

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit("newVolunteerOpportunity", savedOpportunity);
    }

    res.status(201).json({ opportunity: savedOpportunity });
  } catch (error) {
    console.error("Error creating volunteer opportunity:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get all volunteer opportunities
// @route   GET /api/volunteer-opportunities
// @access  Private
const getVolunteerOpportunities = async (req, res) => {
  try {
    const { status, skills, priority, category } = req.query;

    let query = {};

    if (status) query.status = status;
    if (priority) query.priority = priority;
    if (category) query.category = category;
    if (skills) {
      query.requiredSkills = { $in: skills.split(',') };
    }

    const opportunities = await VolunteerOpportunity.find(query)
      .populate("organizerId", "name email")
      .sort({ priority: -1, createdAt: -1 });

    res.json({ opportunities });
  } catch (error) {
    console.error("Error fetching volunteer opportunities:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get volunteer opportunity by ID
// @route   GET /api/volunteer-opportunities/:id
// @access  Private
const getVolunteerOpportunityById = async (req, res) => {
  try {
    const opportunity = await VolunteerOpportunity.findById(req.params.id)
      .populate("organizerId", "name email")
      .populate("volunteers.userId", "name email");

    if (!opportunity) {
      return res.status(404).json({ message: "Volunteer opportunity not found" });
    }

    res.json({ opportunity });
  } catch (error) {
    console.error("Error fetching volunteer opportunity:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Apply for volunteer opportunity
// @route   POST /api/volunteer-opportunities/:id/apply
// @access  Private
const applyForOpportunity = async (req, res) => {
  try {
    const opportunity = await VolunteerOpportunity.findById(req.params.id);

    if (!opportunity) {
      return res.status(404).json({ message: "Volunteer opportunity not found" });
    }

    // MANDATORY PAYMENT CHECK: Calculate required payment for volunteer delivery
    const distance = req.body.distance || 0;
    const paymentInfo = calculatePaymentAmount({
      distance,
      type: 'volunteer'
    });
    
    // Check if payment is provided and matches required amount
    const providedAmount = req.body.paymentAmount || 0;
    if (providedAmount < paymentInfo.totalAmount) {
      return res.status(402).json({
        success: false,
        message: `Payment required for volunteer delivery: ${paymentInfo.totalAmount} PKR (Fixed: ${paymentInfo.fixedAmount} PKR + Delivery: ${paymentInfo.deliveryCharges} PKR)`,
        paymentRequired: true,
        requiredAmount: paymentInfo.totalAmount,
        breakdown: paymentInfo.breakdown
      });
    }
    
    // Verify payment status
    if (req.body.paymentStatus !== 'completed') {
      return res.status(402).json({
        success: false,
        message: 'Payment must be completed before volunteering for delivery',
        paymentRequired: true,
        requiredAmount: paymentInfo.totalAmount
      });
    }
    
    logger.info('Volunteer delivery payment validated', {
      userId: req.user.id,
      opportunityId: opportunity._id,
      requiredAmount: paymentInfo.totalAmount,
      providedAmount,
      paymentStatus: req.body.paymentStatus
    });

    // Check if user already applied
    const existingApplication = opportunity.volunteers.find(
      (vol) => vol.userId.toString() === req.user.id
    );

    if (existingApplication) {
      return res.status(400).json({ message: "You have already applied for this opportunity" });
    }

    // Check if opportunity is full
    if (opportunity.currentVolunteers >= opportunity.maxVolunteers) {
      return res.status(400).json({ message: "This opportunity is full" });
    }

    // Add volunteer application with payment info
    opportunity.volunteers.push({
      userId: req.user.id,
      userName: req.user.name,
      status: "pending",
      paymentAmount: paymentInfo.totalAmount,
      paymentStatus: 'completed',
      stripePaymentIntentId: req.body.stripePaymentIntentId || null,
      appliedAt: new Date()
    });

    opportunity.currentVolunteers += 1;

    const updatedOpportunity = await opportunity.save();

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit("volunteerOpportunityUpdated", {
        opportunityId: opportunity._id,
        currentVolunteers: opportunity.currentVolunteers,
        status: opportunity.status,
      });
    }

    res.json({ 
      message: "Application submitted successfully",
      opportunity: updatedOpportunity 
    });
  } catch (error) {
    console.error("Error applying for opportunity:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Update volunteer opportunity
// @route   PUT /api/volunteer-opportunities/:id
// @access  Private (Organizer only)
const updateVolunteerOpportunity = async (req, res) => {
  try {
    const opportunity = await VolunteerOpportunity.findById(req.params.id);

    if (!opportunity) {
      return res.status(404).json({ message: "Volunteer opportunity not found" });
    }

    // Check if user is the organizer
    if (opportunity.organizerId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized to update this opportunity" });
    }

    const {
      title,
      description,
      requiredSkills,
      startDate,
      endDate,
      address,
      latitude,
      longitude,
      maxVolunteers,
      status,
      priority,
      category,
    } = req.body;

    // Update fields
    if (title) opportunity.title = title;
    if (description) opportunity.description = description;
    if (requiredSkills) opportunity.requiredSkills = requiredSkills;
    if (startDate) opportunity.startDate = startDate;
    if (endDate) opportunity.endDate = endDate;
    if (address) opportunity.address = address;
    if (latitude && longitude) {
      opportunity.location = {
        type: "Point",
        coordinates: [longitude, latitude],
      };
    }
    if (maxVolunteers) opportunity.maxVolunteers = maxVolunteers;
    if (status) opportunity.status = status;
    if (priority) opportunity.priority = priority;
    if (category) opportunity.category = category;

    const updatedOpportunity = await opportunity.save();

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit("volunteerOpportunityUpdated", {
        opportunityId: opportunity._id,
        currentVolunteers: opportunity.currentVolunteers,
        status: opportunity.status,
      });
    }

    res.json({ opportunity: updatedOpportunity });
  } catch (error) {
    console.error("Error updating volunteer opportunity:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Delete volunteer opportunity
// @route   DELETE /api/volunteer-opportunities/:id
// @access  Private (Organizer only)
const deleteVolunteerOpportunity = async (req, res) => {
  try {
    const opportunity = await VolunteerOpportunity.findById(req.params.id);

    if (!opportunity) {
      return res.status(404).json({ message: "Volunteer opportunity not found" });
    }

    // Check if user is the organizer
    if (opportunity.organizerId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized to delete this opportunity" });
    }

    await VolunteerOpportunity.findByIdAndDelete(req.params.id);

    res.json({ message: "Volunteer opportunity deleted successfully" });
  } catch (error) {
    console.error("Error deleting volunteer opportunity:", error);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  createVolunteerOpportunity,
  getVolunteerOpportunities,
  getVolunteerOpportunityById,
  applyForOpportunity,
  updateVolunteerOpportunity,
  deleteVolunteerOpportunity,
};
