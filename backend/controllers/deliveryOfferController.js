const DeliveryOffer = require("../models/DeliveryOffer");
const VolunteerOffer = require("../models/VolunteerOffer");
const Delivery = require("../models/Delivery");
const Donation = require("../models/Donation");
const Request = require("../models/Request");
const User = require("../models/User");
const Notification = require("../models/Notification");
const { sendEmail } = require("../services/emailService");

// Create delivery offer (when volunteer/delivery person accepts)
const createDeliveryOffer = async (req, res) => {
  try {
    const { itemId, itemType } = req.params;
    const offeredBy = req.user._id;
    const { message, estimatedPickupTime, estimatedDeliveryTime } = req.body;

    console.log("🤝 Creating delivery offer:", { itemId, itemType, offeredBy });
    console.log("🔍 Request params:", req.params);
    console.log("🔍 Request body:", req.body);

    // Normalize itemType to handle case sensitivity
    const normalizedItemType =
      itemType.charAt(0).toUpperCase() + itemType.slice(1).toLowerCase();
    console.log("🔍 Normalized itemType:", normalizedItemType);

    // Validate ObjectId format
    const mongoose = require("mongoose");
    if (!mongoose.Types.ObjectId.isValid(itemId)) {
      console.log("❌ Invalid ObjectId format:", itemId);
      return res.status(400).json({
        success: false,
        message: `Invalid ${normalizedItemType.toLowerCase()} ID format`,
      });
    }

    // Get the item (donation or request)
    let item, approverUserId;
    console.log(`🔍 Searching for ${normalizedItemType} with ID: ${itemId}`);

    // Debug: Show all donations in database
    if (normalizedItemType === "Donation") {
      const allDonations = await Donation.find({}).select(
        "_id title status deliveryOption"
      );
      console.log("🔍 All donations in database:");
      allDonations.forEach((d, i) => {
        console.log(
          `  ${i + 1}. ID: ${d._id}, Title: "${d.title}", Status: ${
            d.status
          }, DeliveryOption: ${d.deliveryOption}`
        );
      });
    }

    if (normalizedItemType === "Donation") {
      item = await Donation.findById(itemId).populate(
        "donorId",
        "name email phone"
      );
      approverUserId = item?.donorId?._id;
      console.log("🔍 Donation query result:", item ? "FOUND" : "NOT FOUND");
    } else {
      item = await Request.findById(itemId).populate(
        "requesterId",
        "name email phone"
      );
      approverUserId = item?.requesterId?._id;
      console.log("🔍 Request query result:", item ? "FOUND" : "NOT FOUND");
    }

    console.log(
      "🔍 Item found:",
      item
        ? {
            id: item._id,
            title: item.title,
            status: item.status,
            verificationStatus: item.verificationStatus,
          }
        : "NOT FOUND"
    );

    if (!item) {
      return res.status(404).json({
        success: false,
        message: `${normalizedItemType.toLowerCase()} not found`,
      });
    }

    // Check status based on item type
    let isAvailable = false;
    if (normalizedItemType === "Donation") {
      isAvailable = item.status === "available"; // Donations use 'available' status
      console.log(
        `🔍 Donation status check: ${item.status} === 'available' = ${isAvailable}`
      );
    } else {
      isAvailable = item.verificationStatus === "pending"; // Requests use 'pending' verification status
      console.log(
        `🔍 Request status check: ${item.verificationStatus} === 'pending' = ${isAvailable}`
      );
    }

    console.log("🔍 Availability check:", {
      itemType: normalizedItemType,
      status: item.status,
      verificationStatus: item.verificationStatus,
      isAvailable,
    });

    if (!isAvailable) {
      console.log(
        `❌ Item not available for delivery. Status: ${item.status}, VerificationStatus: ${item.verificationStatus}`
      );
      return res.status(400).json({
        success: false,
        message: `${normalizedItemType} is not available for delivery. Current status: ${
          item.status || item.verificationStatus
        }`,
      });
    }

    // Check if user already has a pending offer for this item
    const existingOffer = await DeliveryOffer.findOne({
      itemId,
      itemType: normalizedItemType,
      offeredBy,
      status: "pending",
    });

    if (existingOffer) {
      return res.status(400).json({
        success: false,
        message: "You already have a pending offer for this item",
      });
    }

    // Determine offer type based on the item's delivery option
    let offerType = "delivery"; // Default to paid delivery

    if (normalizedItemType === "Donation") {
      // For donations, check the deliveryOption field
      if (item.deliveryOption === "Volunteer Delivery") {
        offerType = "volunteer";
      } else if (item.deliveryOption === "Paid Delivery") {
        offerType = "delivery";
      }
    } else if (normalizedItemType === "Request") {
      // For requests, check the metadata.deliveryOption field
      if (
        item.metadata &&
        item.metadata.deliveryOption === "Volunteer Delivery"
      ) {
        offerType = "volunteer";
      } else if (
        item.metadata &&
        item.metadata.deliveryOption === "Paid Delivery"
      ) {
        offerType = "delivery";
      }
    }

    console.log(
      `🎯 Offer type determined: ${offerType} (based on delivery option: ${
        item.deliveryOption || item.metadata?.deliveryOption
      })`
    );

    // Calculate payment amount (FULL price, commission will be applied later)
    let estimatedEarning = 0;
    if (offerType === "delivery" && normalizedItemType === "Donation") {
      // For paid delivery donations, get the FULL payment amount from database
      if (item.paymentAmount && item.paymentAmount > 0) {
        // Payment amount in database is the FULL price (before commission)
        estimatedEarning = item.paymentAmount;
        console.log(
          `💰 Using database payment amount: ${estimatedEarning} PKR (FULL price)`
        );
      } else {
        // Fallback calculation if no payment amount in database
        const distance = item.deliveryDistance || 5; // Default 5km if no distance
        let baseFee = 0;
        if (distance <= 3) {
          baseFee = 50;
        } else if (distance <= 5) {
          baseFee = 100;
        } else {
          baseFee = 100 + (distance - 5) * 20;
        }
        estimatedEarning = baseFee; // FULL price (no commission applied yet)
        console.log(
          `💰 Calculated payment amount: ${estimatedEarning} PKR (FULL price) for ${distance}km`
        );
      }
    } else if (offerType === "delivery" && normalizedItemType === "Request") {
      // For paid delivery requests, get from metadata
      if (item.metadata && item.metadata.paymentAmount) {
        estimatedEarning = item.metadata.paymentAmount;
        console.log(
          `💰 Using request payment amount: ${estimatedEarning} PKR (FULL price)`
        );
      } else {
        estimatedEarning = 100; // Default 100 PKR (FULL price, not after commission)
        console.log(
          `💰 Using default request payment: ${estimatedEarning} PKR (FULL price)`
        );
      }
    }

    // Create delivery offer with correct field names
    const deliveryOffer = new DeliveryOffer({
      itemId,
      itemType: normalizedItemType.toLowerCase(), // 'donation' or 'request'
      ownerId: approverUserId, // The donor or requester who owns the item
      deliveryPersonId: offeredBy, // The delivery person making the offer
      estimatedEarning: estimatedEarning, // Payment FULL price (commission will be applied when displaying)
      message: message || "I would like to help with this delivery.",
      estimatedPickupTime,
      estimatedDeliveryTime,
    });

    await deliveryOffer.save();

    // Populate delivery person data
    await deliveryOffer.populate("deliveryPersonId", "name email phone");

    // Send real-time notification to approver
    const io = req.app.locals.io;
    const notificationData = {
      offerId: deliveryOffer._id,
      itemId,
      itemType: normalizedItemType,
      itemTitle: item.title,
      offeredByName: deliveryOffer.deliveryPersonId.name,
      offeredByPhone: deliveryOffer.deliveryPersonId.phone,
      offeredByEmail: deliveryOffer.deliveryPersonId.email,
      offerType,
      message: deliveryOffer.message,
      estimatedPickupTime,
      estimatedDeliveryTime,
      createdAt: deliveryOffer.createdAt,
    };

    io.to(`user_${approverUserId}`).emit(
      "delivery_offer_received",
      notificationData
    );

    // Create in-app notification
    const notification = new Notification({
      userId: approverUserId,
      title: `${
        offerType === "volunteer" ? "Volunteer" : "Delivery Person"
      } Offer Received`,
      message: `${deliveryOffer.deliveryPersonId.name} wants to help with "${item.title}". Please review and approve.`,
      type: "delivery_offer",
      data: {
        offerId: deliveryOffer._id,
        itemId,
        itemType: normalizedItemType,
      },
    });
    await notification.save();

    // Send email notification
    const approver =
      normalizedItemType === "Donation" ? item.donorId : item.requesterId;
    if (approver && approver.email) {
      try {
        await sendEmail({
          to: approver.email,
          subject: `${
            offerType === "volunteer" ? "Volunteer" : "Delivery Person"
          } Offer for Your ${normalizedItemType}`,
          html: `
            <h2>New Delivery Offer</h2>
            <p>Hello ${approver.name},</p>
            <p><strong>${
              deliveryOffer.deliveryPersonId.name
            }</strong> has offered to help with your ${normalizedItemType.toLowerCase()} "${
            item.title
          }".</p>
            <p><strong>Message:</strong> ${deliveryOffer.message}</p>
            <p><strong>Contact:</strong> ${
              deliveryOffer.deliveryPersonId.phone
            }</p>
            ${
              estimatedPickupTime
                ? `<p><strong>Estimated Pickup:</strong> ${new Date(
                    estimatedPickupTime
                  ).toLocaleString()}</p>`
                : ""
            }
            <p>Please log into your account to review and approve this offer.</p>
            <p>This offer will expire in 24 hours if not responded to.</p>
          `,
        });

        deliveryOffer.notificationsSent.emailSent = true;
        await deliveryOffer.save();
      } catch (emailError) {
        console.error("Failed to send email notification:", emailError);
      }
    }

    res.json({
      success: true,
      message: "Delivery offer created successfully. Waiting for approval.",
      offer: deliveryOffer,
    });
  } catch (error) {
    console.error("Error creating delivery offer:", error);
    res.status(500).json({
      success: false,
      message: "Server error creating delivery offer",
    });
  }
};

// Get delivery offers for approval (for donors/requesters)
const getDeliveryOffersForApproval = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log("📋 Fetching delivery offers for approval:", userId);
    console.log("🔍 DELIVERY: User ID type:", typeof userId);
    console.log("🔍 DELIVERY: User ID string:", userId.toString());

    // First, let's see all delivery offers in the database
    const allOffers = await DeliveryOffer.find({});
    console.log("🔍 DELIVERY: Total offers in database:", allOffers.length);
    console.log(
      "🔍 DELIVERY: All offers:",
      allOffers.map((o) => ({
        id: o._id,
        ownerId: o.ownerId,
        ownerIdString: o.ownerId?.toString(),
        ownerIdType: typeof o.ownerId,
        status: o.status,
        itemType: o.itemType,
        matchesUser: o.ownerId?.toString() === userId.toString(),
      }))
    );

    // Check if any offers match this user
    const matchingOffers = allOffers.filter(
      (o) => o.ownerId?.toString() === userId.toString()
    );
    console.log(
      "🔍 DELIVERY: Matching offers for user:",
      matchingOffers.length
    );

    const offers = await DeliveryOffer.find({
      ownerId: userId,
      status: "pending",
    })
      .populate("deliveryPersonId", "name email phone")
      .sort({ createdAt: -1 });

    console.log("🔍 DELIVERY: Found offers for user:", offers.length);

    // Manually populate itemId based on itemType to avoid schema issues
    const populatedOffers = [];
    for (const offer of offers) {
      let item;
      if (offer.itemType === "donation") {
        item = await Donation.findById(offer.itemId);
      } else if (offer.itemType === "request") {
        item = await Request.findById(offer.itemId);
      }

      if (item && offer.deliveryPersonId) {
        // Get owner information (donor or requester)
        let ownerInfo = {};
        let pickupLocation = "";
        let deliveryLocation = "";

        if (offer.itemType === "donation") {
          // For donations, get donor info
          const donor = await User.findById(item.donorId);
          if (donor) {
            ownerInfo = {
              id: donor._id,
              name: donor.name,
              email: donor.email,
              phone: donor.phone,
            };
          }
          pickupLocation = item.pickupAddress || "Location to be determined";
          deliveryLocation = "To be determined by requester";
        } else if (offer.itemType === "request") {
          // For requests, get requester info
          const requester = await User.findById(item.userId);
          if (requester) {
            ownerInfo = {
              id: requester._id,
              name: requester.name,
              email: requester.email,
              phone: requester.phone,
            };
          }
          pickupLocation = "To be determined by donor";
          deliveryLocation =
            item.metadata?.pickupAddress || "Location to be determined";
        }

        populatedOffers.push({
          id: offer._id,
          itemId: item._id,
          itemType: offer.itemType,
          itemTitle: item.title || item.foodType,
          itemDescription: item.description,
          // Delivery person info
          offeredBy: {
            id: offer.deliveryPersonId._id,
            name: offer.deliveryPersonId.name,
            email: offer.deliveryPersonId.email,
            phone: offer.deliveryPersonId.phone,
          },
          // Owner info (donor/requester)
          owner: ownerInfo,
          // Location info
          pickupLocation: pickupLocation,
          deliveryLocation: deliveryLocation,
          // Payment info
          message: offer.message,
          estimatedCost: Math.round(offer.estimatedEarning * 0.9), // Apply 10% commission
          grossAmount: offer.estimatedEarning, // Full amount before commission
          commission: Math.round(offer.estimatedEarning * 0.1), // 10% commission
          offerType: offer.offerType || "delivery",
          createdAt: offer.createdAt,
          expiresAt: offer.expiresAt,
        });
      }
    }

    console.log("✅ DELIVERY: Populated offers:", populatedOffers.length);
    console.log("✅ DELIVERY: Sending response:", {
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });

    res.json({
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });
  } catch (error) {
    console.error("Error fetching delivery offers:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching delivery offers",
    });
  }
};

// Approve delivery offer
const approveDeliveryOffer = async (req, res) => {
  try {
    const { offerId } = req.params;
    const approverId = req.user._id;
    const { message } = req.body;

    console.log("✅ Approving delivery offer:", { offerId, approverId });

    // First get the offer without populate to check itemType
    const offer = await DeliveryOffer.findById(offerId);

    if (!offer) {
      return res.status(404).json({
        success: false,
        message: "Delivery offer not found",
      });
    }

    // Now populate based on itemType
    let populatedOffer;
    if (offer.itemType === "donation") {
      populatedOffer = await DeliveryOffer.findById(offerId)
        .populate("deliveryPersonId", "name email phone")
        .populate({
          path: "itemId",
          model: "Donation",
        });
    } else {
      populatedOffer = await DeliveryOffer.findById(offerId)
        .populate("deliveryPersonId", "name email phone")
        .populate({
          path: "itemId",
          model: "Request",
        });
    }

    if (populatedOffer.ownerId.toString() !== approverId.toString()) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to approve this offer",
      });
    }

    if (populatedOffer.status !== "pending") {
      return res.status(400).json({
        success: false,
        message: "Offer is no longer pending",
      });
    }

    // Update offer status
    populatedOffer.status = "approved";
    populatedOffer.approverResponse = {
      message: message || "Offer approved",
      respondedAt: new Date(),
      respondedBy: approverId,
    };
    await populatedOffer.save();

    // Create actual delivery record
    const delivery = new Delivery({
      itemId: populatedOffer.itemId._id,
      itemType: populatedOffer.itemType === "donation" ? "Donation" : "Request", // Fix enum case
      deliveryPerson: populatedOffer.deliveryPersonId._id,
      donor: populatedOffer.itemType === "donation" ? approverId : null,
      requester: populatedOffer.itemType === "request" ? approverId : null,
      deliveryType:
        populatedOffer.offerType === "volunteer" ? "volunteer" : "paid",
      status: "assigned",
      assignedAt: new Date(),
      scheduledPickupTime: populatedOffer.estimatedPickupTime,
      scheduledDeliveryTime: populatedOffer.estimatedDeliveryTime,
      // Add required location data
      pickupLocation: {
        address:
          populatedOffer.itemId.address ||
          req.user.address ||
          "Address to be confirmed",
        coordinates: populatedOffer.itemId.coordinates || [],
      },
      deliveryLocation: {
        address: "To be confirmed by requester", // Will be updated when requester provides address
        coordinates: [],
      },
    });

    await delivery.save();

    // Link delivery to offer
    populatedOffer.deliveryId = delivery._id;
    await populatedOffer.save();

    // Update item status to show it's being delivered
    if (populatedOffer.itemType === "donation") {
      await Donation.findByIdAndUpdate(populatedOffer.itemId._id, {
        assignedTo: populatedOffer.deliveryPersonId._id,
        status: "assigned_for_delivery",
      });
    } else {
      await Request.findByIdAndUpdate(populatedOffer.itemId._id, {
        assignedTo: populatedOffer.deliveryPersonId._id,
        status: "assigned_for_delivery",
      });
    }

    // Send notifications to delivery person
    const io = req.app.locals.io;
    io.to(`user_${populatedOffer.deliveryPersonId._id}`).emit(
      "delivery_offer_approved",
      {
        offerId: populatedOffer._id,
        deliveryId: delivery._id,
        itemTitle: populatedOffer.itemId.title,
        approverName: req.user.name,
        message: populatedOffer.approverResponse.message,
      }
    );

    // Create notification for delivery person
    const notification = new Notification({
      userId: populatedOffer.deliveryPersonId._id,
      title: "Delivery Offer Approved!",
      message: `Your offer for "${populatedOffer.itemId.title}" has been approved. You can now proceed with the delivery.`,
      type: "delivery_approved",
      data: { deliveryId: delivery._id, offerId: populatedOffer._id },
    });
    await notification.save();

    // Send email to delivery person/volunteer
    if (populatedOffer.deliveryPersonId.email) {
      try {
        const isVolunteer = populatedOffer.offerType === "volunteer";
        const itemOwnerType =
          populatedOffer.itemType === "donation" ? "donor" : "requester";

        await sendEmail({
          to: populatedOffer.deliveryPersonId.email,
          subject: `${
            isVolunteer ? "Volunteer" : "Delivery"
          } Offer Approved - Care Connect`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #28a745;">🎉 Your ${
                isVolunteer ? "Volunteer" : "Delivery"
              } Offer Has Been Approved!</h2>
              <p>Hello <strong>${
                populatedOffer.deliveryPersonId.name
              }</strong>,</p>
              
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <p><strong>Item:</strong> ${populatedOffer.itemId.title}</p>
                <p><strong>Type:</strong> ${populatedOffer.itemType}</p>
                <p><strong>Approved by:</strong> ${req.user.name}</p>
                ${
                  populatedOffer.approverResponse.message
                    ? `<p><strong>Message:</strong> ${populatedOffer.approverResponse.message}</p>`
                    : ""
                }
              </div>
              
              <h3>📋 Next Steps:</h3>
              <ul>
                <li>✅ Check your delivery dashboard for pickup details</li>
                <li>📞 Contact the ${itemOwnerType}: ${
            req.user.phone || req.user.email
          }</li>
                <li>📍 Coordinate pickup time and location</li>
                <li>🚚 Complete the delivery and update status</li>
              </ul>
              
              <div style="background-color: #e7f3ff; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <p><strong>💡 Tip:</strong> Please confirm pickup time with the ${itemOwnerType} before heading out!</p>
              </div>
              
              <p>Thank you for helping our community! 🙏</p>
              <p><em>- Care Connect Team</em></p>
            </div>
          `,
        });

        console.log(
          `✅ Approval email sent to ${
            isVolunteer ? "volunteer" : "delivery person"
          }: ${populatedOffer.deliveryPersonId.email}`
        );
      } catch (emailError) {
        console.error(
          "Failed to send approval email to delivery person:",
          emailError
        );
      }
    }

    // ALSO send confirmation email to the donor/requester
    if (req.user.email) {
      try {
        const isVolunteer = populatedOffer.offerType === "volunteer";
        const userType =
          populatedOffer.itemType === "donation" ? "donor" : "requester";

        await sendEmail({
          to: req.user.email,
          subject: `${
            isVolunteer ? "Volunteer" : "Delivery Person"
          } Confirmed for Your ${populatedOffer.itemType} - Care Connect`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #007bff;">✅ ${
                isVolunteer ? "Volunteer" : "Delivery Person"
              } Confirmed!</h2>
              <p>Hello <strong>${req.user.name}</strong>,</p>
              
              <p>Great news! <strong>${
                populatedOffer.deliveryPersonId.name
              }</strong> will help with your ${populatedOffer.itemType.toLowerCase()} "${
            populatedOffer.itemId.title
          }".</p>
              
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <h3>📞 Contact Information:</h3>
                <p><strong>Name:</strong> ${
                  populatedOffer.deliveryPersonId.name
                }</p>
                <p><strong>Phone:</strong> ${
                  populatedOffer.deliveryPersonId.phone || "Not provided"
                }</p>
                <p><strong>Email:</strong> ${
                  populatedOffer.deliveryPersonId.email
                }</p>
              </div>
              
              <h3>📋 What's Next:</h3>
              <ul>
                <li>📞 The ${
                  isVolunteer ? "volunteer" : "delivery person"
                } will contact you to coordinate pickup</li>
                <li>📍 Prepare the ${populatedOffer.itemType.toLowerCase()} for pickup</li>
                <li>⏰ Be available at the agreed pickup time</li>
                <li>✅ Confirm delivery completion in your dashboard</li>
              </ul>
              
              <div style="background-color: #fff3cd; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <p><strong>⚠️ Important:</strong> Please ensure the ${populatedOffer.itemType.toLowerCase()} is ready for pickup at the scheduled time.</p>
              </div>
              
              <p>Thank you for using Care Connect to help your community! 🌟</p>
              <p><em>- Care Connect Team</em></p>
            </div>
          `,
        });

        console.log(
          `✅ Confirmation email sent to ${userType}: ${req.user.email}`
        );
      } catch (emailError) {
        console.error(
          "Failed to send confirmation email to donor/requester:",
          emailError
        );
      }
    }

    res.json({
      success: true,
      message: "Delivery offer approved successfully",
      data: {
        offerId: populatedOffer._id,
        deliveryId: delivery._id,
        status: "approved",
      },
    });
  } catch (error) {
    console.error("Error approving delivery offer:", error);
    res.status(500).json({
      success: false,
      message: "Failed to approve delivery offer",
      error: error.message,
    });
  }
};

// Reject delivery offer
const rejectDeliveryOffer = async (req, res) => {
  try {
    const { offerId } = req.params;
    const approverId = req.user._id;
    const { message } = req.body;

    console.log("❌ Rejecting delivery offer:", { offerId, approverId });

    const offer = await DeliveryOffer.findById(offerId)
      .populate("deliveryPersonId", "name email phone")
      .populate("itemId");

    if (!offer) {
      return res.status(404).json({
        success: false,
        message: "Delivery offer not found",
      });
    }

    if (offer.ownerId.toString() !== approverId.toString()) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to reject this offer",
      });
    }

    if (offer.status !== "pending") {
      return res.status(400).json({
        success: false,
        message: "Offer is no longer pending",
      });
    }

    // Update offer status
    offer.status = "rejected";
    offer.approverResponse = {
      message: message || "Offer rejected",
      respondedAt: new Date(),
      respondedBy: approverId,
    };
    await offer.save();

    // Send notification to delivery person
    const io = req.app.locals.io;
    io.to(`user_${offer.deliveryPersonId._id}`).emit(
      "delivery_offer_rejected",
      {
        offerId: offer._id,
        itemTitle: offer.itemId.title,
        approverName: req.user.name,
        message: offer.approverResponse.message,
      }
    );

    // Create notification for delivery person
    const notification = new Notification({
      userId: offer.deliveryPersonId._id,
      title: "Delivery Offer Declined",
      message: `Your offer for "${offer.itemId.title}" was declined. You can try other delivery opportunities.`,
      type: "delivery_rejected",
      data: { offerId: offer._id },
    });
    await notification.save();

    res.json({
      success: true,
      message: "Delivery offer rejected",
    });
  } catch (error) {
    console.error("Error rejecting delivery offer:", error);
    res.status(500).json({
      success: false,
      message: "Server error rejecting delivery offer",
    });
  }
};

// Get accepted delivery offers from donors (for delivery persons/volunteers)
const getAcceptedDeliveryOffersFromDonors = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log(
      "📋 Fetching accepted delivery offers from donors for user:",
      userId
    );

    // Get all approved delivery offers where the current user is the delivery person
    const acceptedOffers = await DeliveryOffer.find({
      deliveryPersonId: userId,
      status: "approved",
    })
      .populate("itemId")
      .populate("ownerId", "name email phone")
      .sort({ createdAt: -1 });

    console.log("🔍 Found accepted offers:", acceptedOffers.length);

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
          estimatedEarning: Math.round(offer.estimatedEarning * 0.9), // Apply 10% commission
          status: offer.status,
          approverResponse: offer.approverResponse,
          deliveryId: offer.deliveryId,
          createdAt: offer.createdAt,
          approvedAt: offer.approverResponse?.respondedAt,
        });
      }
    }

    console.log("✅ Populated accepted offers:", populatedOffers.length);

    res.json({
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });
  } catch (error) {
    console.error("Error fetching accepted delivery offers:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching accepted delivery offers",
    });
  }
};

// Get accepted delivery offers from requesters (for delivery persons/volunteers)
const getAcceptedDeliveryOffersFromRequesters = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log(
      "📋 Fetching accepted delivery offers from requesters for user:",
      userId
    );

    // Get all approved delivery offers where the current user is the delivery person
    // and the item type is 'request'
    const acceptedOffers = await DeliveryOffer.find({
      deliveryPersonId: userId,
      status: "approved",
      itemType: "request", // Only requests
    })
      .populate("itemId")
      .populate("ownerId", "name email phone")
      .sort({ createdAt: -1 });

    console.log(
      "🔍 Found accepted offers from requesters:",
      acceptedOffers.length
    );

    // Manually populate item details for requests
    const populatedOffers = [];
    for (const offer of acceptedOffers) {
      const item = await Request.findById(offer.itemId);

      if (item && offer.ownerId) {
        populatedOffers.push({
          id: offer._id,
          itemId: item._id,
          itemType: offer.itemType,
          itemTitle: item.title || item.foodType,
          itemDescription: item.description,
          requesterId: {
            id: offer.ownerId._id,
            name: offer.ownerId.name,
            email: offer.ownerId.email,
            phone: offer.ownerId.phone,
          },
          requesterName: offer.ownerId.name,
          requesterPhone: offer.ownerId.phone,
          message: offer.message,
          estimatedEarning: Math.round(offer.estimatedEarning * 0.9), // Apply 10% commission
          status: offer.status,
          approverResponse: offer.approverResponse,
          deliveryId: offer.deliveryId,
          createdAt: offer.createdAt,
          approvedAt: offer.approverResponse?.respondedAt,
        });
      }
    }

    console.log(
      "✅ Populated accepted offers from requesters:",
      populatedOffers.length
    );

    res.json({
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });
  } catch (error) {
    console.error(
      "Error fetching accepted delivery offers from requesters:",
      error
    );
    res.status(500).json({
      success: false,
      message: "Server error fetching accepted delivery offers from requesters",
    });
  }
};

// Get accepted delivery offers for donors (for donors to see offers they've accepted)
const getAcceptedDeliveryOffersForDonors = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log("📋 Fetching accepted delivery offers for donor:", userId);

    // Debug: Check if there are any delivery offers for this user at all
    const allDeliveryOffers = await DeliveryOffer.find({
      ownerId: userId,
    });
    console.log(
      "🔍 All delivery offers for this user (any status):",
      allDeliveryOffers.length
    );
    allDeliveryOffers.forEach((offer) => {
      console.log(
        `  - Offer ID: ${offer._id}, Status: ${offer.status}, ItemType: ${offer.itemType}, OwnerId: ${offer.ownerId}`
      );
    });

    // Get all approved delivery offers where the current user is the owner (donor/requester)
    const acceptedOffers = await DeliveryOffer.find({
      ownerId: userId,
      status: "approved",
    })
      .populate("deliveryPersonId", "name email phone")
      .populate("itemId")
      .sort({ createdAt: -1 });

    console.log(
      "🔍 Found accepted delivery offers for donor:",
      acceptedOffers.length
    );

    // Debug: Log all delivery offers for this user (regardless of status)
    const allOffers = await DeliveryOffer.find({
      ownerId: userId,
    }).populate("deliveryPersonId", "name email phone");

    console.log(
      "🔍 All delivery offers for donor (all statuses):",
      allOffers.length
    );
    allOffers.forEach((offer) => {
      console.log(
        `  - Offer ID: ${offer._id}, Status: ${offer.status}, Delivery Person: ${offer.deliveryPersonId?.name}`
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

      if (item && offer.deliveryPersonId) {
        populatedOffers.push({
          id: offer._id,
          itemId: item._id,
          itemType: offer.itemType,
          itemTitle: item.title || item.foodType,
          itemDescription: item.description,
          deliveryPersonId: {
            id: offer.deliveryPersonId._id,
            name: offer.deliveryPersonId.name,
            email: offer.deliveryPersonId.email,
            phone: offer.deliveryPersonId.phone,
          },
          message: offer.message,
          estimatedEarning: Math.round(offer.estimatedEarning * 0.9), // Apply 10% commission
          status: offer.status,
          approverResponse: offer.approverResponse,
          deliveryId: offer.deliveryId,
          createdAt: offer.createdAt,
          approvedAt: offer.approverResponse?.respondedAt,
        });
      }
    }

    console.log(
      "✅ Populated accepted delivery offers for donor:",
      populatedOffers.length
    );

    res.json({
      success: true,
      offers: populatedOffers,
      count: populatedOffers.length,
    });
  } catch (error) {
    console.error("Error fetching accepted delivery offers for donor:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching accepted delivery offers for donor",
    });
  }
};

// Get volunteer dashboard stats
const getVolunteerDashboardStats = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log("📊 Fetching volunteer dashboard stats for user:", userId);

    // Get volunteer offers (where user is delivery person and offer type is volunteer)
    const volunteerOffers = await DeliveryOffer.find({
      deliveryPersonId: userId,
      status: { $in: ["approved", "completed"] },
    })
      .populate("itemId")
      .populate("ownerId", "name email phone")
      .sort({ createdAt: -1 });

    // Calculate stats
    const totalPoints = volunteerOffers.reduce((sum, offer) => {
      // For volunteer offers, calculate points based on distance and type
      let points = 0;
      if (offer.itemType === "donation") {
        const distance = offer.itemId?.deliveryDistance || 5;
        if (distance <= 3) points = 20;
        else if (distance <= 5) points = 30;
        else points = 30 + (distance - 5) * 5;
      } else if (offer.itemType === "request") {
        const distance = offer.itemId?.metadata?.deliveryDistance || 5;
        if (distance <= 3) points = 25;
        else if (distance <= 5) points = 35;
        else points = 35 + (distance - 5) * 5;
      }
      return sum + points;
    }, 0);

    const completedDeliveries = volunteerOffers.filter(
      (offer) => offer.status === "completed"
    ).length;
    const activeDeliveries = volunteerOffers.filter(
      (offer) => offer.status === "approved"
    ).length;

    // Get available volunteer opportunities
    const availableDonations = await Donation.countDocuments({
      deliveryOption: "Volunteer Delivery",
      status: "available",
      verificationStatus: "approved",
    });

    const availableRequests = await Request.countDocuments({
      "metadata.deliveryOption": "Volunteer Delivery",
      verificationStatus: "approved",
    });

    const availableOpportunities = availableDonations + availableRequests;

    // Calculate volunteer hours (estimate based on completed deliveries)
    const totalVolunteerHours = completedDeliveries * 2; // Assume 2 hours per delivery

    // Calculate people helped
    const peopleHelped = completedDeliveries * 3; // Assume 3 people helped per delivery

    // Food type breakdown
    const foodTypeBreakdown = {};
    volunteerOffers.forEach((offer) => {
      if (offer.itemType === "donation" && offer.itemId?.foodCategory) {
        const category = offer.itemId.foodCategory;
        foodTypeBreakdown[category] = (foodTypeBreakdown[category] || 0) + 1;
      }
    });

    // Recent activity
    const recentActivity = volunteerOffers.slice(0, 5).map((offer) => ({
      id: offer._id,
      type: "volunteer_delivery",
      title: offer.itemId?.title || "Volunteer Delivery",
      status: offer.status,
      points:
        offer.itemType === "donation"
          ? offer.itemId?.deliveryDistance <= 3
            ? 20
            : offer.itemId?.deliveryDistance <= 5
            ? 30
            : 30 + (offer.itemId?.deliveryDistance - 5) * 5
          : offer.itemId?.metadata?.deliveryDistance <= 3
          ? 25
          : offer.itemId?.metadata?.deliveryDistance <= 5
          ? 35
          : 35 + (offer.itemId?.metadata?.deliveryDistance - 5) * 5,
      createdAt: offer.createdAt,
      completedAt: offer.status === "completed" ? offer.updatedAt : null,
    }));

    const stats = {
      totalPoints,
      availableOpportunities,
      completedDeliveries,
      activeDeliveries,
      totalVolunteerHours,
      peopleHelped,
      foodTypeBreakdown,
      recentActivity,
    };

    console.log("✅ Volunteer dashboard stats calculated:", stats);

    res.json({
      success: true,
      stats,
    });
  } catch (error) {
    console.error("Error fetching volunteer dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Server error fetching volunteer dashboard stats",
    });
  }
};

// Debug endpoint to check database state
const debugAcceptedOffers = async (req, res) => {
  try {
    const userId = req.user._id;

    console.log("🔍 DEBUG: Checking database state for user:", userId);

    // Check all delivery offers
    const allDeliveryOffers = await DeliveryOffer.find({})
      .populate("ownerId", "name email")
      .populate("deliveryPersonId", "name email");
    console.log(
      "🔍 All delivery offers in database:",
      allDeliveryOffers.length
    );

    // Check all volunteer offers
    const allVolunteerOffers = await VolunteerOffer.find({})
      .populate("ownerId", "name email")
      .populate("volunteerId", "name email");
    console.log(
      "🔍 All volunteer offers in database:",
      allVolunteerOffers.length
    );

    // Check offers for this specific user
    const userDeliveryOffers = await DeliveryOffer.find({ ownerId: userId });
    const userVolunteerOffers = await VolunteerOffer.find({ ownerId: userId });

    console.log("🔍 Delivery offers for this user:", userDeliveryOffers.length);
    console.log(
      "🔍 Volunteer offers for this user:",
      userVolunteerOffers.length
    );

    res.json({
      success: true,
      debug: {
        totalDeliveryOffers: allDeliveryOffers.length,
        totalVolunteerOffers: allVolunteerOffers.length,
        userDeliveryOffers: userDeliveryOffers.length,
        userVolunteerOffers: userVolunteerOffers.length,
        allDeliveryOffers: allDeliveryOffers.map((offer) => ({
          id: offer._id,
          status: offer.status,
          ownerId: offer.ownerId?._id,
          ownerName: offer.ownerId?.name,
          deliveryPersonId: offer.deliveryPersonId?._id,
          deliveryPersonName: offer.deliveryPersonId?.name,
          itemType: offer.itemType,
        })),
        allVolunteerOffers: allVolunteerOffers.map((offer) => ({
          id: offer._id,
          status: offer.status,
          ownerId: offer.ownerId?._id,
          ownerName: offer.ownerId?.name,
          volunteerId: offer.volunteerId?._id,
          volunteerName: offer.volunteerId?.name,
          itemType: offer.itemType,
        })),
      },
    });
  } catch (error) {
    console.error("❌ Debug error:", error);
    res.status(500).json({
      success: false,
      message: "Debug failed",
      error: error.message,
    });
  }
};

module.exports = {
  createDeliveryOffer,
  getDeliveryOffersForApproval,
  approveDeliveryOffer,
  rejectDeliveryOffer,
  getAcceptedDeliveryOffersFromDonors,
  getAcceptedDeliveryOffersFromRequesters,
  getAcceptedDeliveryOffersForDonors,
  getVolunteerDashboardStats,
  debugAcceptedOffers,
};
