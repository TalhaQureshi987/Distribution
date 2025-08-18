const Volunteer = require("../models/Volunteer");
const User = require("../models/User");

// @desc    Register as volunteer
// @route   POST /api/volunteers
// @access  Private
const registerVolunteer = async (req, res) => {
  try {
    const {
      skills,
      availability,
      address,
      latitude,
      longitude,
    } = req.body;

    // Check if user is already a volunteer
    const existingVolunteer = await Volunteer.findOne({ userId: req.user.id });
    if (existingVolunteer) {
      return res.status(400).json({ message: "User is already registered as a volunteer" });
    }

    // Create volunteer profile
    const volunteer = new Volunteer({
      userId: req.user.id,
      userName: req.user.name,
      email: req.user.email,
      phone: req.user.phone,
      skills: skills || [],
      availability: availability || {},
      address,
      location: {
        type: "Point",
        coordinates: [longitude, latitude],
      },
    });

    const savedVolunteer = await volunteer.save();

    res.status(201).json({ volunteer: savedVolunteer });
  } catch (error) {
    console.error("Error registering volunteer:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get volunteer profile
// @route   GET /api/volunteers/profile
// @access  Private
const getVolunteerProfile = async (req, res) => {
  try {
    const volunteer = await Volunteer.findOne({ userId: req.user.id });
    if (!volunteer) {
      return res.status(404).json({ message: "Volunteer profile not found" });
    }

    res.json({ volunteer });
  } catch (error) {
    console.error("Error fetching volunteer profile:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Update volunteer profile
// @route   PUT /api/volunteers/profile
// @access  Private
const updateVolunteerProfile = async (req, res) => {
  try {
    const {
      skills,
      availability,
      address,
      latitude,
      longitude,
    } = req.body;

    const volunteer = await Volunteer.findOne({ userId: req.user.id });
    if (!volunteer) {
      return res.status(404).json({ message: "Volunteer profile not found" });
    }

    // Update fields
    if (skills) volunteer.skills = skills;
    if (availability) volunteer.availability = availability;
    if (address) volunteer.address = address;
    if (latitude && longitude) {
      volunteer.location = {
        type: "Point",
        coordinates: [longitude, latitude],
      };
    }

    const updatedVolunteer = await volunteer.save();

    res.json({ volunteer: updatedVolunteer });
  } catch (error) {
    console.error("Error updating volunteer profile:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get all volunteers
// @route   GET /api/volunteers
// @access  Private
const getAllVolunteers = async (req, res) => {
  try {
    const { status, skills, location } = req.query;

    let query = {};

    if (status) query.status = status;
    if (skills) {
      query.skills = { $in: skills.split(',') };
    }

    const volunteers = await Volunteer.find(query).sort({ createdAt: -1 });

    res.json({ volunteers });
  } catch (error) {
    console.error("Error fetching volunteers:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get volunteer by ID
// @route   GET /api/volunteers/:id
// @access  Private
const getVolunteerById = async (req, res) => {
  try {
    const volunteer = await Volunteer.findById(req.params.id);
    if (!volunteer) {
      return res.status(404).json({ message: "Volunteer not found" });
    }

    res.json({ volunteer });
  } catch (error) {
    console.error("Error fetching volunteer:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Update volunteer status
// @route   PATCH /api/volunteers/:id/status
// @access  Private (Admin)
const updateVolunteerStatus = async (req, res) => {
  try {
    const { status } = req.body;

    const volunteer = await Volunteer.findById(req.params.id);
    if (!volunteer) {
      return res.status(404).json({ message: "Volunteer not found" });
    }

    volunteer.status = status;
    const updatedVolunteer = await volunteer.save();

    res.json({ volunteer: updatedVolunteer });
  } catch (error) {
    console.error("Error updating volunteer status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  registerVolunteer,
  getVolunteerProfile,
  updateVolunteerProfile,
  getAllVolunteers,
  getVolunteerById,
  updateVolunteerStatus,
};
