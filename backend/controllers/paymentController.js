const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);
const {
  calculateDeliveryFee,
  calculateDistance,
  getCenterCoordinates,
} = require("../utils/deliveryUtils");

// Confirm payment intent
const confirmPayment = async (req, res) => {
  try {
    const { paymentIntentId, type, amount } = req.body;

    if (!paymentIntentId) {
      return res.status(400).json({
        success: false,
        message: "Payment intent ID is required",
      });
    }

    console.log("💳 Confirming payment:", { paymentIntentId, type, amount });

    // Confirm the payment intent with Stripe
    const paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId);

    if (paymentIntent.status === "succeeded") {
      console.log("✅ Payment confirmed successfully");

      return res.status(200).json({
        success: true,
        message: "Payment confirmed successfully",
        paymentIntent: {
          id: paymentIntent.id,
          status: paymentIntent.status,
          amount: paymentIntent.amount,
          currency: paymentIntent.currency,
        },
      });
    } else {
      console.log("❌ Payment not succeeded:", paymentIntent.status);

      return res.status(400).json({
        success: false,
        message: `Payment not completed. Status: ${paymentIntent.status}`,
      });
    }
  } catch (error) {
    console.error("❌ Payment confirmation error:", error);

    return res.status(500).json({
      success: false,
      message: "Payment confirmation failed",
      error: error.message,
    });
  }
};

// Get payment intent status
const getPaymentStatus = async (req, res) => {
  try {
    const { paymentIntentId } = req.params;

    if (!paymentIntentId) {
      return res.status(400).json({
        success: false,
        message: "Payment intent ID is required",
      });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    return res.status(200).json({
      success: true,
      paymentIntent: {
        id: paymentIntent.id,
        status: paymentIntent.status,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        client_secret: paymentIntent.client_secret,
      },
    });
  } catch (error) {
    console.error("❌ Get payment status error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to get payment status",
      error: error.message,
    });
  }
};

// Create donation payment intent
const createDonationPaymentIntent = async (req, res) => {
  try {
    const { amount, distance, latitude, longitude, deliveryOption } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid payment amount",
      });
    }

    console.log("💳 Creating donation payment intent:", {
      amount,
      distance,
      deliveryOption,
    });

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: "pkr",
      metadata: {
        type: "donation",
        distance: distance?.toString() || "0",
        deliveryOption: deliveryOption || "Self delivery",
        latitude: latitude?.toString() || "0",
        longitude: longitude?.toString() || "0",
      },
    });

    console.log("✅ Payment intent created:", paymentIntent.id);

    return res.status(200).json({
      success: true,
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      amount: amount,
    });
  } catch (error) {
    console.error("❌ Create donation payment intent error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create payment intent",
      error: error.message,
    });
  }
};

// Create request payment intent
const createRequestPaymentIntent = async (req, res) => {
  try {
    const { amount, distance, latitude, longitude, deliveryOption } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid payment amount",
      });
    }

    console.log("💳 Creating request payment intent:", {
      amount,
      distance,
      deliveryOption,
    });

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: "pkr",
      metadata: {
        type: "request",
        distance: distance?.toString() || "0",
        deliveryOption: deliveryOption || "Self delivery",
        latitude: latitude?.toString() || "0",
        longitude: longitude?.toString() || "0",
      },
    });

    console.log("✅ Payment intent created:", paymentIntent.id);

    return res.status(200).json({
      success: true,
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      amount: amount,
    });
  } catch (error) {
    console.error("❌ Create request payment intent error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create payment intent",
      error: error.message,
    });
  }
};

// Create registration payment intent
const createRegistrationPaymentIntent = async (req, res) => {
  try {
    const { amount } = req.body;
    const registrationAmount = amount || 500; // Default 500 PKR

    console.log("💳 Creating registration payment intent:", {
      amount: registrationAmount,
    });

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(registrationAmount * 100), // Convert to cents
      currency: "pkr",
      metadata: {
        type: "registration",
      },
    });

    console.log("✅ Registration payment intent created:", paymentIntent.id);

    return res.status(200).json({
      success: true,
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      amount: registrationAmount,
    });
  } catch (error) {
    console.error("❌ Create registration payment intent error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create registration payment intent",
      error: error.message,
    });
  }
};

// Calculate payment preview
const calculatePaymentPreview = async (req, res) => {
  try {
    const { type, distance, latitude, longitude, deliveryOption } = req.body;

    console.log("💰 Calculating payment preview:", {
      type,
      distance,
      deliveryOption,
    });

    let fixedAmount = 0;
    let deliveryCharges = 0;
    let totalAmount = 0;

    if (type === "donate") {
      // For donations, only delivery charges apply
      if (deliveryOption === "Paid Delivery" && distance > 0) {
        deliveryCharges = calculateDeliveryFee(distance);
      }
      totalAmount = deliveryCharges;
    } else if (type === "request") {
      // For requests, 100 PKR service fee + delivery charges
      fixedAmount = 100; // Service fee
      if (deliveryOption === "Paid Delivery" && distance > 0) {
        deliveryCharges = calculateDeliveryFee(distance);
      }
      totalAmount = fixedAmount + deliveryCharges;
    }

    console.log("💰 Payment breakdown:", {
      fixedAmount,
      deliveryCharges,
      totalAmount,
    });

    return res.status(200).json({
      success: true,
      paymentInfo: {
        fixedAmount,
        deliveryCharges,
        totalAmount,
        distance: distance || 0,
        deliveryOption: deliveryOption || "Self delivery",
      },
    });
  } catch (error) {
    console.error("❌ Calculate payment preview error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to calculate payment preview",
      error: error.message,
    });
  }
};

// Get delivery rates
const getDeliveryRates = async (req, res) => {
  try {
    const rates = {
      "0-3km": 50,
      "3-5km": 100,
      "5km+": "100 + 20 per additional km",
    };

    return res.status(200).json({
      success: true,
      rates,
    });
  } catch (error) {
    console.error("❌ Get delivery rates error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to get delivery rates",
      error: error.message,
    });
  }
};

// Placeholder functions for compatibility
const confirmPaymentIntent = async (req, res) => {
  return res.status(200).json({ success: true, message: "Payment confirmed" });
};

const confirmPaymentEndpoint = async (req, res) => {
  return res.status(200).json({ success: true, message: "Payment confirmed" });
};

const processRegistrationFee = async (req, res) => {
  return res
    .status(200)
    .json({ success: true, message: "Registration fee processed" });
};

const getPaidUsersWithDetails = async (req, res) => {
  return res.status(200).json({ success: true, users: [] });
};

const getAllPayments = async (req, res) => {
  return res.status(200).json({ success: true, payments: [] });
};

const getDeliveryPayments = async (req, res) => {
  return res.status(200).json({ success: true, payments: [] });
};

const getRevenueAnalytics = async (req, res) => {
  return res.status(200).json({ success: true, analytics: {} });
};

module.exports = {
  confirmPayment,
  getPaymentStatus,
  createDonationPaymentIntent,
  createRequestPaymentIntent,
  createRegistrationPaymentIntent,
  calculatePaymentPreview,
  getDeliveryRates,
  confirmPaymentIntent,
  confirmPaymentEndpoint,
  processRegistrationFee,
  getPaidUsersWithDetails,
  getAllPayments,
  getDeliveryPayments,
  getRevenueAnalytics,
};
