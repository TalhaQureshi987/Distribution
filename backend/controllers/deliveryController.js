const User = require("../models/User");
const Delivery = require("../models/Delivery");
const Donation = require("../models/Donation");
const Request = require("../models/Request");
const Earning = require("../models/Earning");
const Notification = require("../models/Notification");
const Payment = require("../models/Payment");
const CommissionSettings = require("../models/CommissionSettings");
const DeliveryOffer = require("../models/DeliveryOffer");
const { logger } = require("../utils/logger");

// -----------------------------------------------------------------------------
// UNIFIED DELIVERY & EARNING SYSTEM WITH COMMISSION DEDUCTION
// -----------------------------------------------------------------------------

// Enhanced get available deliveries with real data from donations and requests
const getAvailableDeliveries = async (req, res) => {
  try {
    console.log(
      "🚚💰 Fetching available delivery opportunities with earning potential..."
    );

    // Get commission settings
    const commissionSettings = await CommissionSettings.getCurrentSettings();
    const commissionRate = commissionSettings.deliveryCommissionRate || 0.15;

    // Get available donation deliveries that need delivery
    const donationDeliveries = await Donation.find({
      "metadata.deliveryOption": "Paid Delivery",
      status: "verified",
      deliveryStatus: { $in: ["pending", null] },
      assignedDeliveryPerson: null,
    })
      .populate("donorId", "name phone email location")
      .populate("requesterId", "name phone email location")
      .sort({ createdAt: -1 })
      .limit(20);

    // Get available request deliveries that need delivery
    const requestDeliveries = await Request.find({
      "metadata.deliveryOption": "Paid Delivery",
      status: "verified",
      deliveryStatus: { $in: ["pending", null] },
      assignedDeliveryPerson: null,
    })
      .populate("userId", "name phone email location")
      .sort({ createdAt: -1 })
      .limit(20);

    // Format donation deliveries
    const formattedDonations = donationDeliveries.map((donation) => {
      // Use actual payment amount from donation metadata
      const actualPaymentAmount =
        donation.paymentAmount || donation.metadata?.paymentAmount || 0;
      const totalEarning = actualPaymentAmount;
      const companyCommission = Math.round(totalEarning * commissionRate);
      const netEarning = totalEarning - companyCommission;

      return {
        id: donation._id,
        type: "donation",
        title: donation.title,
        description: donation.description,
        foodType: donation.foodType,
        quantity: donation.quantity,
        pickupLocation: donation.pickupLocation,
        deliveryLocation: donation.requesterId?.location || "To be determined",
        donor: {
          id: donation.donorId?._id,
          name: donation.donorId?.name,
          phone: donation.donorId?.phone,
          email: donation.donorId?.email,
        },
        requester: donation.requesterId
          ? {
              id: donation.requesterId._id,
              name: donation.requesterId.name,
              phone: donation.requesterId.phone,
              email: donation.requesterId.email,
            }
          : null,
        urgency: donation.urgency || "medium",
        estimatedDistance: donation.estimatedDistance,
        createdAt: donation.createdAt,
        estimatedEarning: totalEarning,
        netEarning: netEarning,
        companyCommission: companyCommission,
        earningBreakdown: {
          baseRate: actualPaymentAmount,
          distanceBonus: 0,
          total: totalEarning,
          companyCommission: companyCommission,
          netAmount: netEarning,
          commissionRate: `${commissionRate * 100}%`,
        },
      };
    });

    // Format request deliveries
    const formattedRequests = requestDeliveries.map((request) => {
      // Use actual delivery fee from request metadata
      const actualDeliveryFee = request.metadata?.deliveryFee || 0;
      const totalEarning = actualDeliveryFee;
      const companyCommission = Math.round(totalEarning * commissionRate);
      const netEarning = totalEarning - companyCommission;

      return {
        id: request._id,
        type: "request",
        title: request.title,
        description: request.description,
        foodType: request.foodType,
        quantity: request.quantity,
        pickupLocation: "To be determined by donor",
        deliveryLocation: request.deliveryLocation,
        requester: {
          id: request.requesterId?._id,
          name: request.requesterId?.name,
          phone: request.requesterId?.phone,
          email: request.requesterId?.email,
        },
        urgency: request.urgency || "medium",
        estimatedDistance: request.estimatedDistance,
        createdAt: request.createdAt,
        estimatedEarning: totalEarning,
        netEarning: netEarning,
        companyCommission: companyCommission,
        earningBreakdown: {
          baseRate: actualDeliveryFee,
          distanceBonus: 0,
          total: totalEarning,
          companyCommission: companyCommission,
          netAmount: netEarning,
          commissionRate: `${commissionRate * 100}%`,
        },
      };
    });

    // Combine and sort all deliveries
    const allDeliveries = [...formattedDonations, ...formattedRequests].sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
    );

    console.log(
      `✅ Found ${allDeliveries.length} delivery opportunities (${formattedDonations.length} donations, ${formattedRequests.length} requests)`
    );

    res.json({
      success: true,
      deliveries: allDeliveries,
      count: allDeliveries.length,
      breakdown: {
        donations: formattedDonations.length,
        requests: formattedRequests.length,
      },
      commissionInfo: {
        rate: `${commissionRate * 100}%`,
        description: "Company commission deducted from delivery payments",
      },
      message: `${
        allDeliveries.length
      } delivery opportunities available with net earnings after ${
        commissionRate * 100
      }% commission`,
    });
  } catch (error) {
    console.error("❌ Error fetching delivery opportunities:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching delivery opportunities",
    });
  }
};

// Enhanced accept delivery to create offer instead of direct assignment
const acceptDelivery = async (req, res) => {
  try {
    const { deliveryId } = req.params;
    const deliveryPersonId = req.user._id;
    const { message, estimatedPickupTime, estimatedDeliveryTime } = req.body;

    console.log("🤝 DELIVERY: Creating delivery offer for item:", {
      deliveryId,
      deliveryPersonId,
    });

    // Find the item (donation or request) by deliveryId
    // First check if it's a donation
    let item = await Donation.findById(deliveryId);
    let itemType = "Donation";

    if (!item) {
      // Check if it's a request
      item = await Request.findById(deliveryId);
      itemType = "Request";
    }

    if (!item) {
      return res.status(404).json({
        success: false,
        message: "Item not found",
      });
    }

    // Create delivery offer instead of direct assignment
    const deliveryOfferController = require("./deliveryOfferController");

    // Set up request params for delivery offer creation
    req.params.itemId = deliveryId;
    req.params.itemType = itemType;
    req.body = { message, estimatedPickupTime, estimatedDeliveryTime };

    // Call delivery offer creation
    return await deliveryOfferController.createDeliveryOffer(req, res);
  } catch (error) {
    console.error("❌ DELIVERY: Error creating delivery offer:", error);
    res.status(500).json({
      success: false,
      message: "Server error creating delivery offer",
    });
  }
};

// Create earning record for completed delivery
const createDeliveryEarning = async (delivery, remarks) => {
  try {
    console.log("💰 Processing earning for completed delivery:", delivery._id);

    // Get commission settings
    const commissionSettings = await CommissionSettings.getCurrentSettings();
    const commissionRate = commissionSettings.deliveryCommissionRate || 0.15;

    // Calculate earning based on delivery fee or default calculation
    const totalEarning = delivery.deliveryFee || 50;

    // Calculate company commission
    const companyCommission = Math.round(totalEarning * commissionRate);
    const netEarning = totalEarning - companyCommission;

    const earning = new Earning({
      userId: delivery.deliveryPerson,
      deliveryId: delivery._id,
      amount: netEarning,
      type: "delivery",
      status: "pending",
      description: `Delivery completion earning - ${
        delivery.items?.[0]?.name || "Food delivery"
      }`,
      earnedAt: new Date(),
      companyCommission: companyCommission,
      commissionRate: commissionRate,
      remarks: remarks || "Delivery completed successfully",
    });

    await earning.save();

    // Update user's total earnings
    const user = await User.findById(delivery.deliveryPerson);
    user.totalEarnings = (user.totalEarnings || 0) + netEarning;
    user.pendingEarnings = (user.pendingEarnings || 0) + netEarning;
    await user.save();

    // Create notification
    const notification = new Notification({
      userId: delivery.deliveryPerson,
      title: "Money Earned!",
      message: `Congratulations! You earned ${netEarning} for completing the delivery. Total pending earnings: ${user.pendingEarnings}`,
      type: "earning_added",
      data: {
        earningId: earning._id,
        amount: netEarning,
        totalPending: user.pendingEarnings,
      },
    });
    await notification.save();

    console.log("✅ Earning processed successfully");
    return earning;
  } catch (error) {
    console.error("❌ Error processing earning:", error);
    return null;
  }
};

// Get delivery dashboard statistics
const getDeliveryDashboardStats = async (req, res) => {
  try {
    const deliveryPersonId = req.user._id;

    console.log(
      "📊 Fetching delivery dashboard stats for user:",
      deliveryPersonId
    );

    // Get completed deliveries count
    const completedDeliveries = await Delivery.countDocuments({
      deliveryPerson: deliveryPersonId,
      status: "completed",
    });

    // Get available deliveries count
    const availableDeliveries = await Delivery.countDocuments({
      status: "pending",
      deliveryPerson: null,
    });

    // Get total earnings
    const earnings = await Earning.find({ userId: deliveryPersonId });
    const totalEarned = earnings.reduce(
      (sum, earning) => sum + earning.amount,
      0
    );
    const availableEarnings = earnings
      .filter((earning) => earning.status === "available")
      .reduce((sum, earning) => sum + earning.amount, 0);

    // Get recent deliveries with details
    const recentDeliveries = await Delivery.find({
      deliveryPerson: deliveryPersonId,
    })
      .populate("itemId", "title description foodType")
      .populate("donor", "name")
      .populate("requester", "name")
      .sort({ createdAt: -1 })
      .limit(5);

    // Get deliveries by status
    const deliveriesByStatus = await Delivery.aggregate([
      { $match: { deliveryPerson: deliveryPersonId } },
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
    ]);

    const statusBreakdown = {};
    deliveriesByStatus.forEach((item) => {
      statusBreakdown[item._id] = item.count;
    });

    const stats = {
      totalEarned,
      availableEarnings,
      completedDeliveries,
      availableDeliveries,
      pendingDeliveries: statusBreakdown.pending || 0,
      inProgressDeliveries:
        (statusBreakdown.assigned || 0) +
        (statusBreakdown.accepted || 0) +
        (statusBreakdown.picked_up || 0) +
        (statusBreakdown.in_transit || 0),
      recentActivity: recentDeliveries.map((delivery) => ({
        id: delivery._id,
        title: delivery.itemId?.title || "Delivery",
        status: delivery.status,
        donor: delivery.donor?.name || "Unknown",
        requester: delivery.requester?.name || "Unknown",
        createdAt: delivery.createdAt,
        earning: delivery.netEarning || 0,
      })),
    };

    console.log("✅ Delivery dashboard stats calculated:", stats);

    res.json({
      success: true,
      stats,
    });
  } catch (error) {
    console.error("❌ Error fetching delivery dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch delivery dashboard statistics",
      error: error.message,
    });
  }
};

// Create delivery offer for a donation or request
const createDeliveryOffer = async (req, res) => {
  try {
    const { deliveryType, itemId } = req.params;
    const deliveryPersonId = req.user._id;

    // Verify delivery person is verified
    const deliveryPerson = await User.findById(deliveryPersonId);
    if (!deliveryPerson.isIdentityVerified) {
      return res.status(403).json({
        success: false,
        message: "Identity verification required to offer delivery services",
      });
    }

    // Find the item (donation or request)
    let item, ownerId;
    if (deliveryType === "donation") {
      item = await Donation.findById(itemId);
      ownerId = item?.donorId;
    } else if (deliveryType === "request") {
      item = await Request.findById(itemId);
      ownerId = item?.requesterId;
    }

    if (!item) {
      return res.status(404).json({
        success: false,
        message: `${deliveryType} not found`,
      });
    }

    // Check if delivery person already made an offer for this item
    const existingOffer = await DeliveryOffer.findOne({
      itemId,
      itemType: deliveryType,
      deliveryPersonId,
      status: { $in: ["pending", "approved"] },
    });

    if (existingOffer) {
      return res.status(400).json({
        success: false,
        message: "You have already made an offer for this delivery",
      });
    }

    // Calculate estimated earning (you can adjust this logic)
    let estimatedEarning = 0;
    if (deliveryType === "donation") {
      // For paid delivery donations, get the payment amount from database
      if (item.paymentAmount && item.paymentAmount > 0) {
        estimatedEarning = item.paymentAmount; // Already after 10% commission
        console.log(
          `💰 Using database payment amount: ${estimatedEarning} PKR (after commission)`
        );
      } else {
        // Fallback calculation
        const distance = item.deliveryDistance || 5;
        let baseFee =
          distance <= 3 ? 50 : distance <= 5 ? 100 : 100 + (distance - 5) * 20;
        estimatedEarning = baseFee * 0.9; // 90% after 10% commission
        console.log(
          `💰 Calculated payment: ${estimatedEarning} PKR for ${distance}km`
        );
      }
    } else if (deliveryType === "request") {
      if (item.metadata && item.metadata.paymentAmount) {
        estimatedEarning = item.metadata.paymentAmount;
        console.log(
          `💰 Using request payment: ${estimatedEarning} PKR (after commission)`
        );
      } else {
        estimatedEarning = 90; // Default 90 PKR (100 - 10% commission)
        console.log(
          `💰 Using default request payment: ${estimatedEarning} PKR`
        );
      }
    }
    // Create delivery offer
    const deliveryOffer = new DeliveryOffer({
      itemId,
      itemType: deliveryType,
      ownerId,
      deliveryPersonId,
      estimatedEarning,
      status: "pending",
      offeredAt: new Date(),
    });

    await deliveryOffer.save();

    // Create notification for owner
    await Notification.create({
      userId: ownerId,
      title: "New Delivery Offer",
      message: `${deliveryPerson.name} wants to deliver your ${deliveryType}`,
      type: "delivery_offer",
      relatedId: deliveryOffer._id,
    });

    res.json({
      success: true,
      message: "Delivery offer submitted successfully",
      offerId: deliveryOffer._id,
    });
  } catch (error) {
    console.error("Error creating delivery offer:", error);
    res.status(500).json({
      success: false,
      message: "Failed to create delivery offer",
    });
  }
};

// Approve delivery offer
const approveDeliveryOffer = async (req, res) => {
  try {
    const { offerId } = req.params;
    const ownerId = req.user._id;

    const offer = await DeliveryOffer.findById(offerId)
      .populate("deliveryPersonId", "name phone email")
      .populate("itemId");

    if (!offer) {
      return res.status(404).json({
        success: false,
        message: "Delivery offer not found",
      });
    }

    // Verify the user owns this item
    if (offer.ownerId.toString() !== ownerId.toString()) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to approve this offer",
      });
    }

    if (offer.status !== "pending") {
      return res.status(400).json({
        success: false,
        message: "Offer has already been processed",
      });
    }

    // Update offer status
    offer.status = "approved";
    offer.approvedAt = new Date();
    await offer.save();

    // Create delivery record
    const delivery = new Delivery({
      donationId: offer.itemType === "donation" ? offer.itemId._id : null,
      requestId: offer.itemType === "request" ? offer.itemId._id : null,
      deliveryPersonId: offer.deliveryPersonId._id,
      status: "assigned",
      estimatedEarning: offer.estimatedEarning,
      assignedAt: new Date(),
    });

    await delivery.save();

    // Update item status
    if (offer.itemType === "donation") {
      await Donation.findByIdAndUpdate(offer.itemId._id, {
        status: "assigned_for_delivery",
        deliveryPersonId: offer.deliveryPersonId._id,
      });
    } else if (offer.itemType === "request") {
      await Request.findByIdAndUpdate(offer.itemId._id, {
        status: "assigned_for_delivery",
        deliveryPersonId: offer.deliveryPersonId._id,
      });
    }

    // Notify delivery person
    await Notification.create({
      userId: offer.deliveryPersonId._id,
      title: "Delivery Offer Approved",
      message: `Your delivery offer has been approved! You can now proceed with the delivery.`,
      type: "delivery_approved",
      relatedId: delivery._id,
    });

    // Send email notification
    try {
      const emailService = require("../services/emailService");
      await emailService.sendEmail({
        to: offer.deliveryPersonId.email,
        subject: "Delivery Offer Approved - Zero Food Waste",
        html: `
          <h2>Your Delivery Offer Has Been Approved!</h2>
          <p>Dear ${offer.deliveryPersonId.name},</p>
          <p>Great news! Your delivery offer has been approved by the ${
            offer.itemType === "donation" ? "donor" : "requester"
          }.</p>
          <p><strong>Delivery Details:</strong></p>
          <ul>
            <li>Item: ${offer.itemId.title || offer.itemId.foodType}</li>
            <li>Type: ${offer.itemType}</li>
            <li>Estimated Earning: PKR ${offer.estimatedEarning || 50}</li>
          </ul>
          <p>Please log into the app to view full delivery details and coordinate with the ${
            offer.itemType === "donation" ? "donor" : "requester"
          }.</p>
          <p>Thank you for helping reduce food waste!</p>
          <p>Best regards,<br>Zero Food Waste Team</p>
        `,
      });
    } catch (emailError) {
      console.error("Error sending email notification:", emailError);
      // Don't fail the main operation if email fails
    }

    res.json({
      success: true,
      message: "Delivery offer approved successfully",
      deliveryId: delivery._id,
    });
  } catch (error) {
    console.error("Error approving delivery offer:", error);
    res.status(500).json({
      success: false,
      message: "Failed to approve delivery offer",
    });
  }
};

// Helper function to get user-friendly status messages
const getStatusMessage = (status) => {
  const statusMessages = {
    assigned: "Delivery has been assigned to you",
    accepted: "Delivery accepted - ready to pick up",
    picked_up: "Item has been picked up and is on the way",
    in_transit: "Delivery is in progress - heading to destination",
    delivered: "Delivery completed successfully",
    completed: "Delivery completed and payment processed",
    cancelled: "Delivery has been cancelled",
  };

  return statusMessages[status] || `Delivery status updated to ${status}`;
};

// Update delivery status (triggers earning when completed)
const updateDeliveryStatus = async (req, res) => {
  try {
    const { deliveryId } = req.params;
    const { status, notes } = req.body;
    const deliveryPersonId = req.user._id;

    console.log("🔄 Updating delivery status:", {
      deliveryId,
      status,
      deliveryPersonId,
    });

    // Find the delivery
    const delivery = await Delivery.findById(deliveryId)
      .populate("itemId")
      .populate("deliveryPerson", "name email phone");

    if (!delivery) {
      return res.status(404).json({
        success: false,
        message: "Delivery not found",
      });
    }

    // Check if user is the delivery person
    if (
      delivery.deliveryPerson._id.toString() !== deliveryPersonId.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "You can only update your own deliveries",
      });
    }

    // Update delivery status
    const oldStatus = delivery.status;
    delivery.status = status;
    delivery.updatedAt = new Date();

    if (notes) {
      delivery.notes = notes;
    }

    // Set completion timestamp if status is completed
    if (status === "completed") {
      delivery.completedAt = new Date();
    }

    await delivery.save();

    // If delivery is completed, update the donation/request status
    if (status === "completed") {
      console.log("✅ Delivery completed, updating item status");

      if (delivery.itemType === "Donation") {
        // Update donation status to completed
        await Donation.findByIdAndUpdate(delivery.itemId._id, {
          status: "completed",
          completedAt: new Date(),
          completionNotes: notes || "Delivery completed successfully",
        });
        console.log("✅ Donation status updated to completed");
      } else if (delivery.itemType === "Request") {
        // Update request status to completed
        await Request.findByIdAndUpdate(delivery.itemId._id, {
          status: "completed",
          completedAt: new Date(),
          completionNotes: notes || "Delivery completed successfully",
        });
        console.log("✅ Request status updated to completed");
      }

      // Update delivery offer status to completed
      const deliveryOffer = await DeliveryOffer.findOne({
        itemId: delivery.itemId._id,
        deliveryPersonId: deliveryPersonId,
        status: "approved",
      });

      if (deliveryOffer) {
        deliveryOffer.status = "completed";
        deliveryOffer.completedAt = new Date();
        await deliveryOffer.save();
        console.log("✅ Delivery offer status updated to completed");
      }

      // Also update volunteer offer status if this is a volunteer delivery
      if (delivery.deliveryType === "volunteer") {
        const VolunteerOffer = require("../models/VolunteerOffer");
        const volunteerOffer = await VolunteerOffer.findOne({
          itemId: delivery.itemId._id,
          volunteerId: deliveryPersonId,
          status: "approved",
        });

        if (volunteerOffer) {
          volunteerOffer.status = "completed";
          volunteerOffer.completedAt = new Date();
          await volunteerOffer.save();
          console.log("✅ Volunteer offer status updated to completed");
        }

        // Update volunteer assignment status if it exists
        const VolunteerAssignment = require("../models/VolunteerAssignment");
        const volunteerAssignment = await VolunteerAssignment.findOne({
          volunteerId: deliveryPersonId,
          donationId: delivery.itemId._id,
          status: { $in: ["assigned", "in_progress"] },
        });

        if (volunteerAssignment) {
          volunteerAssignment.status = "completed";
          volunteerAssignment.completedAt = new Date();
          await volunteerAssignment.save();
          console.log("✅ Volunteer assignment status updated to completed");
        }
      }

      // Create activity log
      try {
        const ActivityLog = require("../models/ActivityLog");
        await ActivityLog.create({
          userId: deliveryPersonId,
          action: "delivery_completed",
          entityType: "delivery",
          entityId: delivery._id,
          details: {
            itemType: delivery.itemType,
            itemId: delivery.itemId._id,
            completionNotes: notes,
          },
        });
        console.log("✅ Activity log created for delivery completion");
      } catch (activityError) {
        console.error("❌ Failed to create activity log:", activityError);
      }

      // Create earning record for completed delivery
      try {
        console.log("💰 Creating earning record for completed delivery");
        const earning = await createDeliveryEarning(delivery, notes);
        if (earning) {
          console.log("✅ Earning record created successfully");

          // Send real-time notification to delivery person about earning
          const io = req.app.locals.io;
          io.to(`user_${deliveryPersonId}`).emit("earning_added", {
            earningId: earning._id,
            amount: earning.amount,
            status: earning.status,
            description: earning.description,
            remarks: earning.remarks,
            deliveryId: delivery._id,
          });
        }
      } catch (earningError) {
        console.error("❌ Failed to create earning record:", earningError);
      }

      // Send notification to donor/requester
      try {
        const Notification = require("../models/Notification");
        const ownerId =
          delivery.itemType === "Donation"
            ? delivery.itemId.donorId
            : delivery.itemId.requesterId;

        await Notification.create({
          userId: ownerId,
          title: "Delivery Completed",
          message: `Your ${delivery.itemType.toLowerCase()} has been delivered successfully by ${
            delivery.deliveryPerson.name
          }.`,
          type: "delivery_completed",
          data: {
            deliveryId: delivery._id,
            itemId: delivery.itemId._id,
            deliveryPersonName: delivery.deliveryPerson.name,
          },
        });
        console.log("✅ Notification sent to owner");
      } catch (notificationError) {
        console.error("❌ Failed to send notification:", notificationError);
      }
    }

    console.log("🎉 Delivery status updated successfully");

    res.json({
      success: true,
      message: `Delivery status updated to ${status}`,
      delivery: {
        id: delivery._id,
        status: delivery.status,
        completedAt: delivery.completedAt,
        updatedAt: delivery.updatedAt,
      },
    });
  } catch (error) {
    console.error("❌ Error updating delivery status:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update delivery status",
      error: error.message,
    });
  }
};

module.exports = {
  acceptDeliveryEnhanced,
  getMyDeliveries,
  updateDeliveryStatus,
  getMyEarnings,
  requestPayout,
  createDeliveryEarning,
};
