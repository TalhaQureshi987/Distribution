const Donation = require("../models/Donation");
const User = require("../models/User");
const { validateDonation } = require("../validators/donationValidator");

// @desc    Create a new donation
// @route   POST /api/donations
// @access  Private
const createDonation = async (req, res) => {
  try {
    const { error } = validateDonation(req.body);
    if (error) {
      return res.status(400).json({ message: error.details[0].message });
    }
    

    const {
      title,
      description,
      foodType,
      quantity,
      quantityUnit,
      expiryDate,
      pickupAddress,
      latitude,
      longitude,
      notes,
      isUrgent,
      images,
    } = req.body;

    // Get donor information from authenticated user
    const donor = await User.findById(req.user.id);
    if (!donor) {
      return res.status(404).json({ message: "User not found" });
    }
    if (!req.body.description || req.body.description.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: "Description cannot be empty",
        field: "description"
      });
    }

   


    const donation = new Donation({
      donorId: req.user.id,
      donorName: donor.name,
      title,
      description,
      foodType,
      quantity,
      quantityUnit,
      expiryDate,
      pickupAddress,
      latitude,
      longitude,
      notes,
      isUrgent: isUrgent || false,
      images: images || [],
      status: "available",
    });

    const savedDonation = await donation.save();

    res.status(201).json({
      message: "Donation created successfully",
      donation: savedDonation,
    });
  } catch (error) {
    console.error("Error creating donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get all available donations with filters
// @route   GET /api/donations
// @access  Private
const getAvailableDonations = async (req, res) => {
  try {
    const {
      foodType,
      location,
      latitude,
      longitude,
      radius,
      isUrgent,
      page = 1,
      limit = 20,
    } = req.query;

    // Build filter object
    const filter = { status: "available" };

    if (foodType) filter.foodType = { $regex: foodType, $options: "i" };
    if (isUrgent !== undefined) filter.isUrgent = isUrgent === "true";

    // Location-based filtering
    if (latitude && longitude && radius) {
      const lat = parseFloat(latitude);
      const lng = parseFloat(longitude);
      const r = parseFloat(radius);

      filter.location = {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [lng, lat],
          },
          $maxDistance: r * 1000, // Convert km to meters
        },
      };
    }

    const skip = (page - 1) * limit;

    const donations = await Donation.find(filter)
      .sort({ createdAt: -1, isUrgent: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate("donorId", "name email phone");

    const total = await Donation.countDocuments(filter);

    res.json({
      donations,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get donation by ID
// @route   GET /api/donations/:id
// @access  Private
const getDonationById = async (req, res) => {
  try {
    const donation = await Donation.findById(req.params.id).populate(
      "donorId",
      "name email phone"
    );

    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    res.json({ donation });
  } catch (error) {
    console.error("Error fetching donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get user's donations
// @route   GET /api/donations/my-donations
// @access  Private
const getUserDonations = async (req, res) => {
  try {
    const donations = await Donation.find({ donorId: req.user.id }).sort({
      createdAt: -1,
    });

    res.json({ donations });
  } catch (error) {
    console.error("Error fetching user donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Reserve a donation
// @route   PATCH /api/donations/:id/reserve
// @access  Private
const reserveDonation = async (req, res) => {
  try {
    const donation = await Donation.findById(req.params.id);

    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    if (donation.status !== "available") {
      return res.status(400).json({ message: "Donation is not available" });
    }

    if (donation.donorId.toString() === req.user.id) {
      return res
        .status(400)
        .json({ message: "Cannot reserve your own donation" });
    }

    // Check if donation has expired
    if (new Date() > donation.expiryDate) {
      donation.status = "expired";
      await donation.save();
      return res.status(400).json({ message: "Donation has expired" });
    }

    donation.status = "reserved";
    donation.reservedBy = req.user.id;
    donation.reservedAt = new Date();
    donation.updatedAt = new Date();

    const updatedDonation = await donation.save();

    res.json({
      message: "Donation reserved successfully",
      donation: updatedDonation,
    });
  } catch (error) {
    console.error("Error reserving donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Update donation status
// @route   PATCH /api/donations/:id/status
// @access  Private
const updateDonationStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = [
      "available",
      "reserved",
      "picked_up",
      "expired",
      "cancelled",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const donation = await Donation.findById(req.params.id);

    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    // Check if user is the donor or admin
    if (
      donation.donorId.toString() !== req.user.id &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({ message: "Not authorized" });
    }

    donation.status = status;
    donation.updatedAt = new Date();

    // Reset reservation if status changes to available
    if (status === "available") {
      donation.reservedBy = undefined;
      donation.reservedAt = undefined;
    }

    const updatedDonation = await donation.save();

    res.json({
      message: "Donation status updated successfully",
      donation: updatedDonation,
    });
  } catch (error) {
    console.error("Error updating donation status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Delete donation
// @route   DELETE /api/donations/:id
// @access  Private
const deleteDonation = async (req, res) => {
  try {
    const donation = await Donation.findById(req.params.id);

    if (!donation) {
      return res.status(404).json({ message: "Donation not found" });
    }

    // Check if user is the donor or admin
    if (
      donation.donorId.toString() !== req.user.id &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // Check if donation can be deleted
    if (donation.status === "reserved" || donation.status === "picked_up") {
      return res
        .status(400)
        .json({ message: "Cannot delete donation with current status" });
    }

    await Donation.findByIdAndDelete(req.params.id);

    res.json({ message: "Donation deleted successfully" });
  } catch (error) {
    console.error("Error deleting donation:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get donations by status
// @route   GET /api/donations/status/:status
// @access  Private
const getDonationsByStatus = async (req, res) => {
  try {
    const { status } = req.params;
    const validStatuses = [
      "available",
      "reserved",
      "picked_up",
      "expired",
      "cancelled",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const donations = await Donation.find({ status })
      .sort({ createdAt: -1 })
      .populate("donorId", "name email phone");

    res.json({ donations });
  } catch (error) {
    console.error("Error fetching donations by status:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get urgent donations
// @route   GET /api/donations/urgent
// @access  Private
const getUrgentDonations = async (req, res) => {
  try {
    const donations = await Donation.find({
      isUrgent: true,
      status: "available",
      expiryDate: { $gt: new Date() },
    })
      .sort({ expiryDate: 1, createdAt: -1 })
      .populate("donorId", "name email phone");

    res.json({ donations });
  } catch (error) {
    console.error("Error fetching urgent donations:", error);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  createDonation,
  getAvailableDonations,
  getDonationById,
  getUserDonations,
  reserveDonation,
  updateDonationStatus,
  deleteDonation,
  getDonationsByStatus,
  getUrgentDonations,
};
