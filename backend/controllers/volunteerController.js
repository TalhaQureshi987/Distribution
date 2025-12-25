const Volunteer = require("../models/Volunteer");
const User = require("../models/User");
const Donation = require("../models/Donation");
const Delivery = require("../models/Delivery");
const Request = require("../models/Request");
const VolunteerOffer = require("../models/VolunteerOffer");
const VolunteerAssignment = require("../models/VolunteerAssignment");
const Notification = require("../models/Notification");
const { sendEmail } = require("../services/emailService");

// Get available deliveries for volunteers (real data)
const getAvailableDeliveries = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;

    console.log("📦 Fetching available deliveries for volunteers");

    // Get available donations that need volunteer delivery
    const availableDonations = await Donation.find({
      "metadata.deliveryOption": "Volunteer Delivery",
      status: { $in: ["verified", "available"] },
      assignedTo: null,
    })
      .populate("donorId", "name phone")
      .sort({ createdAt: -1 })
      .limit(limit);

    // Get available requests that need volunteer delivery
    const availableRequests = await Request.find({
      "metadata.deliveryOption": "Volunteer Delivery",
      status: { $in: ["verified", "available"] },
      assignedTo: null,
    })
      .populate("userId", "name phone")
      .sort({ createdAt: -1 })
      .limit(limit);

    console.log(
      `🔍 Found ${availableDonations.length} volunteer donation deliveries`
    );
    console.log(
      `🔍 Found ${availableRequests.length} volunteer request deliveries`
    );

    // Format donations for volunteer delivery
    const formattedDonations = availableDonations.map((donation) => ({
      id: donation._id,
      type: "donation",
      deliveryType: "donation",
      title: donation.title,
      description: donation.description,
      foodType: donation.metadata?.foodType || donation.foodType,
      quantity: donation.metadata?.quantity || donation.quantity,
      pickupLocation:
        donation.metadata?.pickupAddress || donation.pickupLocation,
      donor: {
        id: donation.donorId?._id,
        name: donation.donorId?.name,
        phone: donation.donorId?.phone,
      },
      urgency: donation.priority || donation.urgency || "medium",
      estimatedDistance: donation.metadata?.distance,
      createdAt: donation.createdAt,
      deliveryOption: donation.metadata?.deliveryOption,
      volunteerPoints: 10,
    }));

    // Format requests for volunteer delivery
    const formattedRequests = availableRequests.map((request) => ({
      id: request._id,
      type: "request",
      deliveryType: "request",
      title: request.title,
      description: request.description,
      foodType: request.metadata?.foodType || request.foodType,
      quantity: request.metadata?.quantity || request.quantity,
      deliveryLocation: request.metadata?.pickupAddress,
      requester: {
        id: request.userId?._id,
        name: request.userId?.name,
        phone: request.userId?.phone,
      },
      urgency: request.priority || "medium",
      estimatedDistance: request.metadata?.distance,
      createdAt: request.createdAt,
      deliveryOption: request.metadata?.deliveryOption,
      volunteerPoints: 15,
    }));

    // Combine all deliveries
    const allDeliveries = [...formattedDonations, ...formattedRequests]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, limit);

    console.log(
      `✅ Found ${allDeliveries.length} available VOLUNTEER deliveries (${formattedDonations.length} donations, ${formattedRequests.length} requests)`
    );

    res.json({
      success: true,
      deliveries: allDeliveries,
      count: allDeliveries.length,
      message: `${allDeliveries.length} volunteer delivery opportunities available`,
    });
  } catch (error) {
    console.error("❌ Error fetching available deliveries:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch available deliveries",
      error: error.message,
    });
  }
};

// Get all volunteers (admin)

// Get volunteer dashboard stats
const getVolunteerDashboardStats = async (req, res) => {
  try {
    const volunteerId = req.user._id;
    const completedDeliveries = await Delivery.countDocuments({
      deliveryPerson: volunteerId,
      deliveryType: "volunteer",
      status: "completed",
    });
    const stats = {
      completedDeliveries,
      availableDeliveries: 5,
      remainingDeliveries: 2,
      totalVolunteerHours: completedDeliveries * 2,
      foodTypeBreakdown: { food: 3, clothes: 1, medicine: 1, other: 0 },
      recentActivity: [],
    };
    res.json({ success: true, stats });
  } catch (error) {
    console.error("❌ Error fetching volunteer dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch volunteer dashboard statistics",
    });
  }
};

// Simple placeholder functions for remaining routes
const createVolunteerOffer = async (req, res) => {
  try {
    const { deliveryType, itemId } = req.params;
    const { message } = req.body;
    const volunteerId = req.user._id;

    console.log("🤝 Creating volunteer offer:", {
      deliveryType,
      itemId,
      volunteerId,
    });

    // Find the item (donation or request)
    let item, ownerId;
    if (deliveryType === "donation") {
      item = await Donation.findById(itemId);
      ownerId = item?.donorId;
    } else if (deliveryType === "request") {
      item = await Request.findById(itemId);
      ownerId = item?.userId;
    }

    console.log("🔍 Volunteer offer creation debug:", {
      deliveryType,
      itemId,
      itemFound: !!item,
      ownerId,
      itemDonorId: item?.donorId,
      itemUserId: item?.userId,
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        message: `${deliveryType} not found`,
      });
    }

    // Check if volunteer already has a pending offer for this item
    const existingOffer = await VolunteerOffer.findOne({
      itemId,
      itemType: deliveryType,
      volunteerId,
      status: { $in: ["pending", "approved"] },
    });

    if (existingOffer) {
      if (existingOffer.status === "pending") {
        return res.status(400).json({
          success: false,
          message:
            "You already have a pending offer for this item. Please wait for approval or rejection.",
        });
      } else if (existingOffer.status === "approved") {
        return res.status(400).json({
          success: false,
          message: "You already have an approved offer for this item.",
        });
      }
    }

    // Create volunteer offer
    const volunteerOffer = new VolunteerOffer({
      itemId,
      itemType: deliveryType,
      ownerId,
      volunteerId,
      message:
        message || "I would like to help with this volunteer opportunity.",
      status: "pending",
      offeredAt: new Date(),
    });

    await volunteerOffer.save();

    console.log("✅ Volunteer offer created:", {
      offerId: volunteerOffer._id,
      itemId,
      itemType: deliveryType,
      ownerId,
      volunteerId,
      status: volunteerOffer.status,
    });

    // Create notification for owner
    await Notification.create({
      userId: ownerId,
      title: "New Volunteer Offer",
      message: `${req.user.name} wants to volunteer for your ${deliveryType}`,
      type: "volunteer_offer",
      data: {
        volunteerId: req.user._id,
        offerId: volunteerOffer._id,
        itemId: itemId,
        itemType: deliveryType,
      },
    });

    // Send email notification
    try {
      const ownerUser = await User.findById(ownerId);
      if (ownerUser && ownerUser.email) {
        await sendEmail({
          to: ownerUser.email,
          subject: "New Volunteer Offer - Zero Food Waste",
          html: `
            <h2>New Volunteer Offer</h2>
            <p>Dear ${ownerUser.name},</p>
            <p>${
              req.user.name
            } has made a volunteer offer for your ${deliveryType}.</p>
            <p><strong>Message:</strong> ${
              message || "I would like to help with this volunteer opportunity."
            }</p>
            <p><strong>Volunteer Details:</strong></p>
            <ul>
              <li>Name: ${req.user.name}</li>
              <li>Email: ${req.user.email}</li>
              <li>Phone: ${req.user.phone}</li>
            </ul>
            <p>Please log into the app to view and manage volunteer offers.</p>
            <p>Best regards,<br>Zero Food Waste Team</p>
          `,
        });
      }
    } catch (emailError) {
      console.error("Error sending email notification:", emailError);
    }

    res.json({
      success: true,
      message: "Volunteer offer submitted successfully",
      offerId: volunteerOffer._id,
    });
  } catch (error) {
    console.error("❌ Error creating volunteer offer:", error);
    res.status(500).json({
      success: false,
      message: "Failed to create volunteer offer",
      error: error.message,
    });
  }
};

// Approve volunteer offer
const approveVolunteerOffer = async (req, res) => {
  try {
    const { offerId } = req.params;
    const offer = await VolunteerOffer.findById(offerId).populate(
      "volunteerId",
      "name email"
    );

    if (!offer || offer.status !== "pending") {
      return res.status(400).json({ success: false, message: "Invalid offer" });
    }

    offer.status = "approved";
    offer.approvedAt = new Date();
    await offer.save();

    console.log("✅ Volunteer offer approved:", {
      offerId: offer._id,
      status: offer.status,
      ownerId: offer.ownerId,
      volunteerId: offer.volunteerId._id,
      itemId: offer.itemId,
      itemType: offer.itemType,
    });

    // Send approval notification
    await Notification.create({
      userId: offer.volunteerId._id,
      title: "Volunteer Offer Approved",
      message: "Your volunteer offer has been approved!",
      type: "volunteer_approved",
    });

    // Send email notification to volunteer
    try {
      if (offer.volunteerId && offer.volunteerId.email) {
        await sendEmail({
          to: offer.volunteerId.email,
          subject: "🎉 Volunteer Offer Approved - Zero Food Waste",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #28a745;">🎉 Your Volunteer Offer Has Been Approved!</h2>
              <p>Hello <strong>${offer.volunteerId.name}</strong>,</p>
              
              <p>Great news! Your volunteer offer has been approved by the donor/requester.</p>
              
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <h3>📋 Next Steps:</h3>
                <ul>
                  <li>✅ Check your volunteer dashboard for delivery details</li>
                  <li>📞 Contact the donor/requester to coordinate pickup</li>
                  <li>📍 Confirm pickup time and location</li>
                  <li>🚚 Complete the delivery and help your community</li>
                </ul>
              </div>
              
              <div style="background-color: #e7f3ff; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <p><strong>💡 Tip:</strong> Please contact the donor/requester as soon as possible to arrange pickup!</p>
              </div>
              
              <p>Thank you for volunteering and making a difference in your community! 🙏</p>
              <p><em>- Zero Food Waste Team</em></p>
            </div>
          `,
        });
        console.log(
          `✅ Approval email sent to volunteer: ${offer.volunteerId.email}`
        );
      }
    } catch (emailError) {
      console.error("Failed to send approval email to volunteer:", emailError);
    }

    res.json({
      success: true,
      message: "Volunteer offer approved successfully",
    });
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: "Failed to approve offer" });
  }
};

// Reject volunteer offer with email notification
const rejectVolunteerOffer = async (req, res) => {
  try {
    const { offerId } = req.params;
    const { reason } = req.body;
    const offer = await VolunteerOffer.findById(offerId).populate(
      "volunteerId",
      "name email"
    );

    if (!offer || offer.status !== "pending") {
      return res.status(400).json({ success: false, message: "Invalid offer" });
    }

    offer.status = "rejected";
    offer.rejectedAt = new Date();
    offer.rejectionReason = reason;
    await offer.save();

    // Send rejection notification
    await Notification.create({
      userId: offer.volunteerId._id,
      title: "Volunteer Offer Rejected",
      message: `Your volunteer offer has been rejected. ${
        reason ? "Reason: " + reason : ""
      }`,
      type: "volunteer_rejected",
    });

    // Send rejection email
    try {
      if (offer.volunteerId.email) {
        await sendEmail({
          to: offer.volunteerId.email,
          subject: "Volunteer Offer Update - Zero Food Waste",
          html: `
            <h2>Volunteer Offer Update</h2>
            <p>Dear ${offer.volunteerId.name},</p>
            <p>We regret to inform you that your volunteer offer has been declined.</p>
            ${reason ? `<p><strong>Reason:</strong> ${reason}</p>` : ""}
            <p>Don't be discouraged! There are many other opportunities to help reduce food waste.</p>
            <p>Thank you for your willingness to help!</p>
            <p>Best regards,<br>Zero Food Waste Team</p>
          `,
        });
      }
    } catch (emailError) {
      console.error("Error sending rejection email:", emailError);
    }

    res.json({
      success: true,
      message: "Volunteer offer rejected successfully",
    });
  } catch (error) {
    res.status(500).json({ success: false, message: "Failed to reject offer" });
  }
};
const getPendingVolunteerOffers = async (req, res) => {
  try {
    const VolunteerOffer = require("../models/VolunteerOffer");
    const User = require("../models/User");
    const Donation = require("../models/Donation");
    const Request = require("../models/Request");

    const offers = await VolunteerOffer.find({ status: "pending" })
      .populate("volunteerId", "name email phone")
      .sort({ createdAt: -1 });

    // Enhance offers with detailed information
    const enhancedOffers = [];
    for (const offer of offers) {
      let item = null;
      let ownerInfo = {};
      let pickupLocation = "";
      let deliveryLocation = "";

      // Get item details based on itemType and itemId
      if (offer.itemType === "donation") {
        item = await Donation.findById(offer.itemId).populate(
          "donorId",
          "name email phone"
        );
        if (item && item.donorId) {
          ownerInfo = {
            id: item.donorId._id,
            name: item.donorId.name,
            email: item.donorId.email,
            phone: item.donorId.phone,
          };
        }
        pickupLocation = item?.pickupAddress || "Location to be determined";
        deliveryLocation = "To be determined by requester";
      } else if (offer.itemType === "request") {
        item = await Request.findById(offer.itemId).populate(
          "userId",
          "name email phone"
        );
        if (item && item.userId) {
          ownerInfo = {
            id: item.userId._id,
            name: item.userId.name,
            email: item.userId.email,
            phone: item.userId.phone,
          };
        }
        pickupLocation = "To be determined by donor";
        deliveryLocation =
          item?.metadata?.pickupAddress || "Location to be determined";
      }

      enhancedOffers.push({
        id: offer._id,
        itemId: item?._id,
        itemType: offer.itemType,
        itemTitle: item?.title || item?.foodType || "Unknown Item",
        itemDescription: item?.description,
        // Volunteer info
        offeredBy: {
          id: offer.volunteerId._id,
          name: offer.volunteerId.name,
          email: offer.volunteerId.email,
          phone: offer.volunteerId.phone,
        },
        // Owner info (donor/requester)
        owner: ownerInfo,
        // Location info
        pickupLocation: pickupLocation,
        deliveryLocation: deliveryLocation,
        // Volunteer specific
        message: offer.message,
        offerType: "volunteer",
        createdAt: offer.createdAt,
        expiresAt: offer.expiresAt,
      });
    }

    res.json({
      success: true,
      offers: enhancedOffers,
      count: enhancedOffers.length,
    });
  } catch (error) {
    console.error("Error fetching volunteer offers:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch volunteer offers",
      error: error.message,
    });
  }
};
const acceptVolunteerDelivery = async (req, res) => {
  res.json({
    success: true,
    message: "Volunteer delivery accepted successfully",
  });
};

// Get accepted volunteer offers
const getAcceptedVolunteerOffers = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log("📋 Fetching accepted volunteer offers for user:", userId);

    // Get all approved volunteer offers where the current user is the volunteer
    const acceptedOffers = await VolunteerOffer.find({
      volunteerId: userId,
      status: "approved",
    })
      .populate("itemId")
      .populate("ownerId", "name email phone")
      .sort({ createdAt: -1 });

    console.log("🔍 Found accepted volunteer offers:", acceptedOffers.length);

    // Manually populate item details based on itemType
    const populatedOffers = [];
    for (const offer of acceptedOffers) {
      let item;
      if (offer.itemType === "donation") {
        item = await Donation.findById(offer.itemId);
      } else if (offer.itemType === "request") {
        item = await Request.findById(offer.itemId);
      }

      if (item && offer.ownerId) {
        populatedOffers.push({
          id: offer._id,
          itemId: item._id,
          itemType: offer.itemType,
          itemTitle: item.title || item.foodType,
          itemDescription: item.description,
          ownerId: {
            id: offer.ownerId._id,
            name: offer.ownerId.name,
            email: offer.ownerId.email,
            phone: offer.ownerId.phone,
          },
          message: offer.message,
          status: offer.status,
          approverResponse: offer.approverResponse,
          createdAt: offer.createdAt,
          approvedAt: offer.approverResponse?.respondedAt,
          completedAt: offer.completedAt,
        });
      }
    }

    console.log(
      "✅ Populated accepted volunteer offers:",
      populatedOffers.length
    );

    res.json({
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });
  } catch (error) {
    console.error("Error fetching accepted volunteer offers:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching accepted volunteer offers",
    });
  }
};

// Get accepted volunteer offers for donors (for donors to see offers they've accepted)
const getAcceptedVolunteerOffersForDonors = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log("📋 Fetching accepted volunteer offers for donor:", userId);

    // Debug: Check if there are any volunteer offers for this user at all
    const allVolunteerOffers = await VolunteerOffer.find({
      ownerId: userId,
    });
    console.log(
      "🔍 All volunteer offers for this user (any status):",
      allVolunteerOffers.length
    );
    allVolunteerOffers.forEach((offer) => {
      console.log(
        `  - Offer ID: ${offer._id}, Status: ${offer.status}, ItemType: ${offer.itemType}, OwnerId: ${offer.ownerId}`
      );
    });

    // Get all approved and completed volunteer offers where the current user is the owner (donor/requester)
    const acceptedOffers = await VolunteerOffer.find({
      ownerId: userId,
      status: { $in: ["approved", "completed"] },
    })
      .populate("volunteerId", "name email phone")
      .populate("itemId")
      .sort({ createdAt: -1 });

    console.log(
      "🔍 Found accepted volunteer offers for donor:",
      acceptedOffers.length
    );

    // Debug: Log all volunteer offers for this user (regardless of status)
    const allOffers = await VolunteerOffer.find({
      ownerId: userId,
    }).populate("volunteerId", "name email phone");

    console.log(
      "🔍 All volunteer offers for donor (all statuses):",
      allOffers.length
    );
    allOffers.forEach((offer) => {
      console.log(
        `  - Offer ID: ${offer._id}, Status: ${offer.status}, Volunteer: ${offer.volunteerId?.name}`
      );
    });

    // Manually populate item details based on itemType
    const populatedOffers = [];
    for (const offer of acceptedOffers) {
      let item;
      if (offer.itemType === "donation") {
        item = await Donation.findById(offer.itemId);
      } else if (offer.itemType === "request") {
        item = await Request.findById(offer.itemId);
      }

      if (item && offer.volunteerId) {
        populatedOffers.push({
          id: offer._id,
          itemId: item._id,
          itemType: offer.itemType,
          itemTitle: item.title || item.foodType,
          itemDescription: item.description,
          volunteerId: {
            id: offer.volunteerId._id,
            name: offer.volunteerId.name,
            email: offer.volunteerId.email,
            phone: offer.volunteerId.phone,
          },
          message: offer.message,
          status: offer.status,
          approverResponse: offer.approverResponse,
          createdAt: offer.createdAt,
          approvedAt: offer.approverResponse?.respondedAt,
          completedAt: offer.completedAt,
        });
      }
    }

    console.log(
      "✅ Populated accepted volunteer offers for donor:",
      populatedOffers.length
    );

    res.json({
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });
  } catch (error) {
    console.error("Error fetching accepted volunteer offers for donor:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching accepted volunteer offers for donor",
    });
  }
};

module.exports = {
  getVolunteerDashboardStats,
  getAvailableDeliveries,
  createVolunteerOffer,
  approveVolunteerOffer,
  rejectVolunteerOffer,
  getPendingVolunteerOffers,
  acceptVolunteerDelivery,
  getAcceptedVolunteerOffers,
  getAcceptedVolunteerOffersForDonors,
};
