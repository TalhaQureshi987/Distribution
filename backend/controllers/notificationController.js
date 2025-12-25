const Notification = require("../models/Notification");
const User = require("../models/User");
const { getIO } = require("../logic/socket");
const { sendEmail } = require("../services/emailService");

// Enhanced notification system for delivery flows
class DeliveryNotificationService {
  // Notify when new volunteer delivery is available
  static async notifyVolunteersNewDelivery(item) {
    try {
      const io = getIO();

      // Handle both donations (with location.coordinates) and requests (with metadata.latitude/longitude)
      let coordinates;
      if (item.location && item.location.coordinates) {
        // Donation format
        coordinates = item.location.coordinates;
      } else if (
        item.metadata &&
        item.metadata.latitude &&
        item.metadata.longitude
      ) {
        // Request format
        coordinates = [item.metadata.longitude, item.metadata.latitude];
      } else {
        console.log("⚠️ No coordinates found for volunteer item:", item._id);
        // Fallback: notify all volunteers
        const volunteers = await User.find({
          role: "volunteer",
          isActive: true,
        });
        console.log(
          `📢 Notifying ${volunteers.length} volunteers (no location filter)`
        );
        return { notifiedCount: volunteers.length };
      }

      // Find all active volunteers in the area
      const volunteers = await User.find({
        role: "volunteer",
        isActive: true,
        "location.coordinates": {
          $near: {
            $geometry: {
              type: "Point",
              coordinates: coordinates,
            },
            $maxDistance: 10000, // 10km radius
          },
        },
      });

      console.log(
        ` Notifying ${volunteers.length} volunteers about new delivery opportunity`
      );

      for (const volunteer of volunteers) {
        // Real-time notification
        io.to(`user_${volunteer._id}`).emit("new_volunteer_delivery", {
          donationId: item._id,
          title: item.title,
          donorName: item.donorId?.name || item.userId?.name || "Anonymous",
          location: item.pickupAddress || item.metadata?.pickupAddress,
          urgency:
            item.urgencyLevel || item.metadata?.isUrgent ? "urgent" : "medium",
          foodType: item.foodType || item.metadata?.foodType,
          message: `New volunteer delivery opportunity: ${item.title}`,
        });

        // Create in-app notification
        await Notification.create({
          userId: volunteer._id,
          type: "volunteer_delivery_available",
          title: "New Volunteer Delivery Available",
          message: `New delivery opportunity: ${item.title} from ${
            item.donorId?.name || item.userId?.name || "Anonymous"
          }`,
          data: {
            donationId: item._id,
            donorName: item.donorId?.name || item.userId?.name,
            location: item.pickupAddress || item.metadata?.pickupAddress,
            urgency:
              item.urgencyLevel || item.metadata?.isUrgent
                ? "urgent"
                : "medium",
          },
        });

        // Send email notification
        if (volunteer.emailNotifications?.volunteerOpportunities !== false) {
          await sendEmail({
            to: volunteer.email,
            subject: "New Volunteer Delivery Opportunity",
            template: "volunteer-delivery-available",
            data: {
              volunteerName: volunteer.name,
              donationTitle: item.title,
              donorName: item.donorId?.name || item.userId?.name || "Anonymous",
              pickupLocation:
                item.pickupAddress || item.metadata?.pickupAddress,
              urgency:
                item.urgencyLevel || item.metadata?.isUrgent
                  ? "urgent"
                  : "medium",
              appUrl: process.env.FRONTEND_URL,
            },
          });
        }
      }

      return { notifiedCount: volunteers.length };
    } catch (error) {
      console.error(" Error notifying volunteers:", error);
      throw error;
    }
  }

  // Notify when new paid delivery is available
  static async notifyDeliveryPersonnelNewDelivery(item, itemType) {
    try {
      const io = getIO();

      // Find all active delivery personnel in the area
      // Handle both donations (with location.coordinates) and requests (with metadata.latitude/longitude)
      let coordinates;
      if (item.location && item.location.coordinates) {
        // Donation format
        coordinates = item.location.coordinates;
      } else if (
        item.metadata &&
        item.metadata.latitude &&
        item.metadata.longitude
      ) {
        // Request format
        coordinates = [item.metadata.longitude, item.metadata.latitude];
      } else {
        console.log("⚠️ No coordinates found for item:", item._id);
        // Fallback: notify all delivery personnel
        const deliveryPersonnel = await User.find({
          role: "delivery",
          isActive: true,
        });
        console.log(
          `📢 Notifying ${deliveryPersonnel.length} delivery personnel (no location filter)`
        );
        return { notifiedCount: deliveryPersonnel.length };
      }

      const deliveryPersonnel = await User.find({
        role: "delivery",
        isActive: true,
        "location.coordinates": {
          $near: {
            $geometry: {
              type: "Point",
              coordinates: coordinates,
            },
            $maxDistance: 15000, // 15km radius for paid deliveries
          },
        },
      });

      console.log(
        ` Notifying ${deliveryPersonnel.length} delivery personnel about new paid delivery`
      );

      for (const deliveryPerson of deliveryPersonnel) {
        // Real-time notification
        io.to(`user_${deliveryPerson._id}`).emit("new_paid_delivery", {
          itemId: item._id,
          itemType: itemType,
          title: item.title,
          ownerName:
            itemType === "donation" ? item.donorId?.name : item.userId?.name,
          location: item.pickupAddress || item.metadata?.pickupAddress,
          paymentAmount:
            item.estimatedPrice ||
            item.paymentAmount ||
            item.metadata?.deliveryFee ||
            0,
          urgency:
            item.urgencyLevel || item.metadata?.isUrgent ? "urgent" : "medium",
          message: `New paid delivery opportunity: ${item.title}`,
        });

        // Create in-app notification
        await Notification.create({
          userId: deliveryPerson._id,
          type: "paid_delivery_available",
          title: "New Paid Delivery Available",
          message: `Earn PKR ${
            item.estimatedPrice ||
            item.paymentAmount ||
            item.metadata?.deliveryFee ||
            0
          } delivering: ${item.title}`,
          data: {
            itemId: item._id,
            itemType: itemType,
            ownerName:
              itemType === "donation" ? item.donorId?.name : item.userId?.name,
            paymentAmount:
              item.estimatedPrice ||
              item.paymentAmount ||
              item.metadata?.deliveryFee ||
              0,
            location: item.pickupAddress || item.metadata?.pickupAddress,
          },
        });

        // Send email notification
        if (
          deliveryPerson.emailNotifications?.deliveryOpportunities !== false
        ) {
          await sendEmail({
            to: deliveryPerson.email,
            subject: "New Paid Delivery Opportunity",
            template: "paid-delivery-available",
            data: {
              deliveryPersonName: deliveryPerson.name,
              itemTitle: item.title,
              ownerName:
                itemType === "donation"
                  ? item.donorId?.name
                  : item.userId?.name,
              paymentAmount:
                item.estimatedPrice ||
                item.paymentAmount ||
                item.metadata?.deliveryFee ||
                0,
              pickupLocation:
                item.pickupAddress || item.metadata?.pickupAddress,
              urgency:
                item.urgencyLevel || item.metadata?.isUrgent
                  ? "urgent"
                  : "medium",
              appUrl: process.env.FRONTEND_URL,
            },
          });
        }
      }

      return { notifiedCount: deliveryPersonnel.length };
    } catch (error) {
      console.error(" Error notifying delivery personnel:", error);
      throw error;
    }
  }

  // Notify when volunteer accepts delivery
  static async notifyVolunteerAcceptance(donation, volunteer) {
    try {
      const io = getIO();

      // Notify donor
      io.to(`user_${donation.donorId._id}`).emit("volunteer_accepted", {
        donationId: donation._id,
        volunteerName: volunteer.name,
        volunteerPhone: volunteer.phone,
        message: `${volunteer.name} has accepted to deliver your donation: ${donation.title}`,
      });

      // Create notification for donor
      await Notification.create({
        userId: donation.donorId._id,
        type: "volunteer_accepted",
        title: "Volunteer Accepted Your Donation",
        message: `${volunteer.name} will deliver your donation: ${donation.title}`,
        data: {
          donationId: donation._id,
          volunteerName: volunteer.name,
          volunteerPhone: volunteer.phone,
        },
      });

      // Send email to donor
      await sendEmail({
        to: donation.donorId.email,
        subject: "Volunteer Accepted Your Donation",
        template: "volunteer-accepted",
        data: {
          donorName: donation.donorId.name,
          donationTitle: donation.title,
          volunteerName: volunteer.name,
          volunteerPhone: volunteer.phone,
          appUrl: process.env.FRONTEND_URL,
        },
      });

      console.log(
        ` Notified donor about volunteer acceptance: ${volunteer.name}`
      );
    } catch (error) {
      console.error(" Error notifying volunteer acceptance:", error);
      throw error;
    }
  }

  // Notify when delivery person accepts paid delivery
  static async notifyDeliveryAcceptance(item, itemType, deliveryPerson) {
    try {
      const io = getIO();
      const ownerId =
        itemType === "donation" ? item.donorId._id : item.userId._id;
      const ownerEmail =
        itemType === "donation" ? item.donorId.email : item.userId.email;
      const ownerName =
        itemType === "donation" ? item.donorId.name : item.userId.name;

      // Notify owner (donor/requester)
      io.to(`user_${ownerId}`).emit("delivery_accepted", {
        itemId: item._id,
        itemType: itemType,
        deliveryPersonName: deliveryPerson.name,
        deliveryPersonPhone: deliveryPerson.phone,
        paymentAmount: item.estimatedPrice || item.paymentAmount,
        message: `${deliveryPerson.name} has accepted to deliver your ${itemType}: ${item.title}`,
      });

      // Create notification for owner
      await Notification.create({
        userId: ownerId,
        type: "delivery_accepted",
        title: `Delivery Person Accepted Your ${itemType}`,
        message: `${deliveryPerson.name} will deliver your ${itemType}: ${item.title}`,
        data: {
          itemId: item._id,
          itemType: itemType,
          deliveryPersonName: deliveryPerson.name,
          deliveryPersonPhone: deliveryPerson.phone,
          paymentAmount: item.estimatedPrice || item.paymentAmount,
        },
      });

      // Send email to owner
      await sendEmail({
        to: ownerEmail,
        subject: `Delivery Person Accepted Your ${itemType}`,
        template: "delivery-accepted",
        data: {
          ownerName: ownerName,
          itemTitle: item.title,
          itemType: itemType,
          deliveryPersonName: deliveryPerson.name,
          deliveryPersonPhone: deliveryPerson.phone,
          paymentAmount: item.estimatedPrice || item.paymentAmount,
          appUrl: process.env.FRONTEND_URL,
        },
      });

      console.log(
        ` Notified ${itemType} owner about delivery acceptance: ${deliveryPerson.name}`
      );
    } catch (error) {
      console.error(" Error notifying delivery acceptance:", error);
      throw error;
    }
  }

  // Notify when volunteer/delivery is rejected
  static async notifyRejection(item, itemType, rejectedBy, reason) {
    try {
      const io = getIO();
      const ownerId =
        itemType === "donation" ? item.donorId._id : item.userId._id;
      const ownerEmail =
        itemType === "donation" ? item.donorId.email : item.userId.email;
      const ownerName =
        itemType === "donation" ? item.donorId.name : item.userId.name;

      // Notify owner
      io.to(`user_${ownerId}`).emit("delivery_rejected", {
        itemId: item._id,
        itemType: itemType,
        rejectedBy: rejectedBy.name,
        reason: reason,
        message: `${rejectedBy.name} cannot deliver your ${itemType}: ${item.title}`,
      });

      // Create notification
      await Notification.create({
        userId: ownerId,
        type: "delivery_rejected",
        title: "Delivery Rejected",
        message: `${rejectedBy.name} cannot deliver your ${itemType}: ${item.title}. Reason: ${reason}`,
        data: {
          itemId: item._id,
          itemType: itemType,
          rejectedBy: rejectedBy.name,
          reason: reason,
        },
      });

      // Send email
      await sendEmail({
        to: ownerEmail,
        subject: `Delivery Update for Your ${itemType}`,
        template: "delivery-rejected",
        data: {
          ownerName: ownerName,
          itemTitle: item.title,
          itemType: itemType,
          rejectedBy: rejectedBy.name,
          reason: reason,
          appUrl: process.env.FRONTEND_URL,
        },
      });

      console.log(` Notified ${itemType} owner about delivery rejection`);
    } catch (error) {
      console.error(" Error notifying delivery rejection:", error);
      throw error;
    }
  }
}

module.exports = DeliveryNotificationService;

// @desc    Get user notifications
// @route   GET /api/notifications
// @access  Private
const getUserNotifications = async (req, res) => {
  try {
    const { page = 1, limit = 20, unreadOnly = false } = req.query;

    let query = { userId: req.user.id };
    if (unreadOnly === "true") {
      query.isRead = false;
    }

    const skip = (page - 1) * limit;

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Notification.countDocuments(query);

    res.json({
      notifications,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching notifications:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Mark notification as read
// @route   PATCH /api/notifications/:id/read
// @access  Private
const markNotificationAsRead = async (req, res) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }

    notification.isRead = true;
    notification.readAt = new Date();
    await notification.save();

    res.json({ notification });
  } catch (error) {
    console.error("Error marking notification as read:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Mark all notifications as read
// @route   PATCH /api/notifications/read-all
// @access  Private
const markAllNotificationsAsRead = async (req, res) => {
  try {
    const result = await Notification.updateMany(
      { userId: req.user.id, isRead: false },
      { isRead: true, readAt: new Date() }
    );

    res.json({
      message: "All notifications marked as read",
      updatedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error("Error marking all notifications as read:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Delete notification
// @route   DELETE /api/notifications/:id
// @access  Private
const deleteNotification = async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }

    res.json({ message: "Notification deleted successfully" });
  } catch (error) {
    console.error("Error deleting notification:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Get unread count
// @route   GET /api/notifications/unread-count
// @access  Private
const getUnreadCount = async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user.id,
      isRead: false,
    });

    res.json({ unreadCount: count });
  } catch (error) {
    console.error("Error getting unread count:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// @desc    Create notification (internal use)
// @route   POST /api/notifications
// @access  Private
const createNotification = async (req, res) => {
  try {
    const {
      userId,
      title,
      message,
      type,
      data,
      priority = "medium",
    } = req.body;

    const notification = new Notification({
      userId,
      title,
      message,
      type,
      data,
      priority,
    });

    const savedNotification = await notification.save();

    res.status(201).json({ notification: savedNotification });
  } catch (error) {
    console.error("Error creating notification:", error);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
  getUnreadCount,
  createNotification,
};
