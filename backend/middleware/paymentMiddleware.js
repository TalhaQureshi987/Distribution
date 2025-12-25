const { logger } = require("../utils/logger");
const { calculateDeliveryFee } = require("../utils/deliveryUtils");

// Payment configuration constants
const PAYMENT_CONFIG = {
  FIXED_DONATION_AMOUNT: 0, // PKR
  FIXED_REQUEST_FEE: 100, // PKR - Base fee for all requests
  CURRENCY: "pkr",
  MIN_DISTANCE_KM: 0,
  MAX_DISTANCE_KM: 50,
};

/**
 * Calculate total payment amount required
 * @param {Object} options - Payment calculation options
 * @param {number} options.distance - Distance in kilometers
 * @param {string} options.type - Type: 'donation', 'request', or 'volunteer'
 * @param {string} options.deliveryOption - Delivery option: 'Self delivery', 'Volunteer Delivery', 'Paid Delivery'
 * @returns {Object} Payment breakdown
 */
const calculatePaymentAmount = (options = {}) => {
  const {
    distance = 0,
    type = "donation",
    deliveryOption = "Self delivery",
  } = options;

  let fixedAmount = 0;
  let deliveryCharges = 0;

  // Add fixed request fee for ALL requests (mandatory service fee)
  if (type === "request") {
    fixedAmount = PAYMENT_CONFIG.FIXED_REQUEST_FEE; // 100 PKR service fee
  }
  // Calculate delivery charges based on delivery option
  if (deliveryOption === "Paid Delivery") {
    // Use minimum distance of 1km if distance is 0 or invalid
    let effectiveDistance = distance > 0 ? distance : 1;

    // Cap maximum distance to prevent extremely high fees
    if (effectiveDistance > 50) {
      effectiveDistance = 50; // Maximum 50km
    }

    // Use centralized delivery fee calculation
    deliveryCharges = calculateDeliveryFee(effectiveDistance);
    console.log(
      `🚚 Delivery charges calculated: ${deliveryCharges} PKR for ${effectiveDistance}km (original: ${distance}km)`
    );
  }

  const totalAmount = fixedAmount + deliveryCharges;

  // IMPORTANT: All requests must have minimum payment (service fee)
  const minimumPayment =
    type === "request" ? PAYMENT_CONFIG.FIXED_REQUEST_FEE : 0;
  const finalAmount = Math.max(totalAmount, minimumPayment);

  const breakdown = {};

  if (type === "request") {
    breakdown["Service Fee"] = `${fixedAmount} PKR (Required for all requests)`;
  }

  if (deliveryCharges > 0) {
    const effectiveDistance = distance > 0 ? distance : 1;
    breakdown[
      "Delivery Charges"
    ] = `${deliveryCharges} PKR (${effectiveDistance}km)`;
  } else if (deliveryOption === "Volunteer Delivery") {
    breakdown["Delivery Charges"] = `0 PKR (Volunteer - FREE)`;
  } else if (deliveryOption === "Self delivery") {
    breakdown["Delivery Charges"] = `0 PKR (Self Pickup)`;
  }

  breakdown["Total Amount"] = `${finalAmount} PKR`;

  return {
    fixedAmount,
    deliveryCharges,
    totalAmount: finalAmount,
    distance,
    type,
    deliveryOption,
    requiresPayment: finalAmount > 0, // Always true for requests
    currency: PAYMENT_CONFIG.CURRENCY,
    breakdown,
  };
};

/**
 * Middleware to validate payment requirements before allowing actions
 */
const validatePaymentRequired = (actionType) => {
  return async (req, res, next) => {
    try {
      const user = await User.findById(req.user.id);
      if (!user) {
        return res.status(404).json({ message: "User not found" });
      }

      // Registration fee required for requesters and delivery personnel
      if (
        (actionType === "request" && user.roles.includes("requester")) ||
        (actionType === "delivery" && user.roles.includes("delivery"))
      ) {
        if (!user.applicationFeePaid) {
          return res.status(402).json({
            message:
              "Registration fee payment required for requesters and delivery personnel",
            paymentRequired: true,
            userRole: user.roles.join(", "),
          });
        }
      }

      // Donors and volunteers do not need to pay registration fee
      if (actionType === "donation" && user.roles.includes("donor")) {
        // Donors can donate without payment
        next();
        return;
      }

      if (actionType === "volunteer" && user.roles.includes("volunteer")) {
        // Volunteers can volunteer without payment
        next();
        return;
      }

      next();
    } catch (error) {
      console.error("Payment validation error:", error);
      res
        .status(500)
        .json({ message: "Server error during payment validation" });
    }
  };
};

/**
 * Middleware to check if payment is completed before allowing access
 */
const requirePaymentCompletion = (itemType = "donation") => {
  return async (req, res, next) => {
    try {
      const { paymentStatus, paymentAmount } = req.body;
      const itemId = req.params.id || req.body.id;

      // Check if payment is required and completed
      if (!paymentStatus || paymentStatus !== "completed") {
        return res.status(402).json({
          success: false,
          message: `Payment of ${
            paymentAmount || PAYMENT_CONFIG.FIXED_DONATION_AMOUNT
          } PKR required to proceed with ${itemType}`,
          paymentRequired: true,
          requiredAmount: paymentAmount || PAYMENT_CONFIG.FIXED_DONATION_AMOUNT,
        });
      }

      logger.info("Payment completion verified", {
        userId: req.user._id,
        itemType,
        itemId,
        paymentAmount,
      });

      next();
    } catch (error) {
      logger.error("Payment completion check error", {
        userId: req.user?._id,
        itemType,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        message: "Payment verification failed",
      });
    }
  };
};

/**
 * Middleware to calculate payment amount
 */
const calculatePaymentAmountMiddleware = async (req, res, next) => {
  try {
    const { deliveryOption } = req.body;

    // Only require payment for "Paid Delivery" option
    if (deliveryOption !== "Paid Delivery") {
      req.paymentInfo = {
        totalAmount: 0,
        deliveryCharges: 0,
        donationFee: 0,
        requiresPayment: false,
      };
      return next();
    }

    // For paid delivery, calculate delivery charges
    const { pickupAddress, deliveryAddress, latitude, longitude } = req.body;

    if (!pickupAddress || !deliveryAddress || !latitude || !longitude) {
      return res.status(400).json({
        message:
          "Pickup address, delivery address, and coordinates are required for paid delivery",
      });
    }

    const deliveryCharges = await calculateDeliveryCharges({
      pickupLat: parseFloat(latitude),
      pickupLng: parseFloat(longitude),
      deliveryAddress,
    });

    const totalAmount = deliveryCharges;

    req.paymentInfo = {
      totalAmount,
      deliveryCharges,
      donationFee: 0,
      requiresPayment: true,
    };

    next();
  } catch (error) {
    console.error("Payment calculation error:", error);
    res.status(500).json({ message: "Error calculating payment amount" });
  }
};

/**
 * Calculate distance between two coordinates using Haversine formula
 */
const calculateDistanceFromCoordinates = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  return Math.round(distance * 100) / 100; // Round to 2 decimal places
};

module.exports = {
  validatePaymentRequired,
  requirePaymentCompletion,
  calculatePaymentAmount,
  calculateDistanceFromCoordinates,
  calculatePaymentAmountMiddleware,
  PAYMENT_CONFIG,
};
