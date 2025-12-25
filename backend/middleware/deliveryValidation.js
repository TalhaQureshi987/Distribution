const Delivery = require('../models/Delivery');
const Earning = require('../models/Earning');
const User = require('../models/User');
const { logger } = require('../utils/logger');

// Validate delivery acceptance
const validateDeliveryAcceptance = async (req, res, next) => {
  try {
    const { deliveryId } = req.params;
    const userId = req.user._id;

    // Check if delivery exists
    const delivery = await Delivery.findById(deliveryId);
    if (!delivery) {
      return res.status(404).json({
        success: false,
        message: 'Delivery not found',
        errorCode: 'DELIVERY_NOT_FOUND'
      });
    }

    // Check if delivery is still available
    if (delivery.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: `Delivery is no longer available. Current status: ${delivery.status}`,
        errorCode: 'DELIVERY_NOT_AVAILABLE',
        currentStatus: delivery.status
      });
    }

    // Check if delivery is already assigned
    if (delivery.deliveryPerson) {
      return res.status(409).json({
        success: false,
        message: 'This delivery has already been accepted by another person',
        errorCode: 'DELIVERY_ALREADY_ASSIGNED',
        assignedTo: delivery.deliveryPerson
      });
    }

    // Check if user is trying to accept their own donation/request
    if (delivery.itemType === 'donation') {
      const donation = await require('../models/Donation').findById(delivery.itemId);
      if (donation && donation.donorId.toString() === userId.toString()) {
        return res.status(400).json({
          success: false,
          message: 'You cannot accept delivery for your own donation',
          errorCode: 'SELF_DELIVERY_NOT_ALLOWED'
        });
      }
    } else if (delivery.itemType === 'request') {
      const request = await require('../models/Request').findById(delivery.itemId);
      if (request && request.requesterId.toString() === userId.toString()) {
        return res.status(400).json({
          success: false,
          message: 'You cannot accept delivery for your own request',
          errorCode: 'SELF_DELIVERY_NOT_ALLOWED'
        });
      }
    }

    // Check if user has too many active deliveries
    const activeDeliveries = await Delivery.countDocuments({
      deliveryPerson: userId,
      status: { $in: ['accepted', 'in_progress'] }
    });

    const maxActiveDeliveries = 5; // Configurable limit
    if (activeDeliveries >= maxActiveDeliveries) {
      return res.status(429).json({
        success: false,
        message: `You have reached the maximum limit of ${maxActiveDeliveries} active deliveries`,
        errorCode: 'MAX_DELIVERIES_EXCEEDED',
        activeCount: activeDeliveries,
        maxAllowed: maxActiveDeliveries
      });
    }

    // Add delivery to request for use in controller
    req.delivery = delivery;
    next();

  } catch (error) {
    logger.error('Delivery acceptance validation error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during delivery validation',
      errorCode: 'VALIDATION_ERROR'
    });
  }
};

// Validate delivery status update
const validateDeliveryStatusUpdate = async (req, res, next) => {
  try {
    const { deliveryId } = req.params;
    const { status } = req.body;
    const userId = req.user._id;

    // Validate status value
    const validStatuses = ['accepted', 'in_progress', 'completed', 'cancelled'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
        errorCode: 'INVALID_STATUS',
        validStatuses
      });
    }

    // Check if delivery exists
    const delivery = await Delivery.findById(deliveryId);
    if (!delivery) {
      return res.status(404).json({
        success: false,
        message: 'Delivery not found',
        errorCode: 'DELIVERY_NOT_FOUND'
      });
    }

    // Check if user is assigned to this delivery
    if (!delivery.deliveryPerson || delivery.deliveryPerson.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'You are not assigned to this delivery',
        errorCode: 'UNAUTHORIZED_DELIVERY_ACCESS'
      });
    }

    // Validate status transitions
    const currentStatus = delivery.status;
    const validTransitions = {
      'pending': ['accepted', 'cancelled'],
      'accepted': ['in_progress', 'cancelled'],
      'in_progress': ['completed', 'cancelled'],
      'completed': [], // Final state
      'cancelled': [] // Final state
    };

    if (!validTransitions[currentStatus] || !validTransitions[currentStatus].includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status transition from '${currentStatus}' to '${status}'`,
        errorCode: 'INVALID_STATUS_TRANSITION',
        currentStatus,
        requestedStatus: status,
        validTransitions: validTransitions[currentStatus]
      });
    }

    // Check if delivery is already completed or cancelled
    if (['completed', 'cancelled'].includes(currentStatus)) {
      return res.status(400).json({
        success: false,
        message: `Cannot update delivery status. Delivery is already ${currentStatus}`,
        errorCode: 'DELIVERY_FINALIZED',
        currentStatus
      });
    }

    // Prevent duplicate completion
    if (status === 'completed' && currentStatus === 'completed') {
      return res.status(400).json({
        success: false,
        message: 'Delivery is already completed',
        errorCode: 'ALREADY_COMPLETED'
      });
    }

    req.delivery = delivery;
    next();

  } catch (error) {
    logger.error('Delivery status update validation error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during status update validation',
      errorCode: 'VALIDATION_ERROR'
    });
  }
};

// Validate payout request
const validatePayoutRequest = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const { amount, paymentMethod } = req.body;

    // Validate amount
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid payout amount greater than 0',
        errorCode: 'INVALID_AMOUNT'
      });
    }

    // Validate payment method
    const validPaymentMethods = ['bank_transfer', 'paypal', 'mobile_money'];
    if (!paymentMethod || !validPaymentMethods.includes(paymentMethod)) {
      return res.status(400).json({
        success: false,
        message: `Invalid payment method. Must be one of: ${validPaymentMethods.join(', ')}`,
        errorCode: 'INVALID_PAYMENT_METHOD',
        validMethods: validPaymentMethods
      });
    }

    // Check minimum payout amount
    const minimumPayout = 100; // PKR 100
    if (amount < minimumPayout) {
      return res.status(400).json({
        success: false,
        message: `Minimum payout amount is PKR ${minimumPayout}`,
        errorCode: 'BELOW_MINIMUM_PAYOUT',
        minimumAmount: minimumPayout,
        requestedAmount: amount
      });
    }

    // Get user's available earnings
    const availableEarnings = await Earning.find({
      user: userId,
      status: 'available'
    });

    const totalAvailable = availableEarnings.reduce((sum, earning) => sum + earning.netAmount, 0);

    if (amount > totalAvailable) {
      return res.status(400).json({
        success: false,
        message: `Insufficient available earnings. You have PKR ${totalAvailable} available for payout`,
        errorCode: 'INSUFFICIENT_EARNINGS',
        availableAmount: totalAvailable,
        requestedAmount: amount
      });
    }

    // Check for recent payout requests
    const recentPayout = await Earning.findOne({
      user: userId,
      status: 'requested',
      'payoutRequest.requestedAt': {
        $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) // Last 24 hours
      }
    });

    if (recentPayout) {
      return res.status(429).json({
        success: false,
        message: 'You have a pending payout request. Please wait for it to be processed before requesting another payout',
        errorCode: 'RECENT_PAYOUT_PENDING',
        pendingPayoutDate: recentPayout.payoutRequest.requestedAt
      });
    }

    // Check daily payout limit
    const dailyPayouts = await Earning.find({
      user: userId,
      status: { $in: ['requested', 'paid'] },
      'payoutRequest.requestedAt': {
        $gte: new Date(Date.now() - 24 * 60 * 60 * 1000)
      }
    });

    const dailyPayoutTotal = dailyPayouts.reduce((sum, earning) => sum + earning.netAmount, 0);
    const dailyLimit = 5000; // PKR 5000 per day

    if (dailyPayoutTotal + amount > dailyLimit) {
      return res.status(429).json({
        success: false,
        message: `Daily payout limit of PKR ${dailyLimit} would be exceeded`,
        errorCode: 'DAILY_LIMIT_EXCEEDED',
        dailyLimit,
        alreadyPaidToday: dailyPayoutTotal,
        requestedAmount: amount,
        remainingLimit: dailyLimit - dailyPayoutTotal
      });
    }

    req.availableEarnings = availableEarnings;
    req.totalAvailable = totalAvailable;
    next();

  } catch (error) {
    logger.error('Payout request validation error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during payout validation',
      errorCode: 'VALIDATION_ERROR'
    });
  }
};

// Validate delivery creation
const validateDeliveryCreation = async (req, res, next) => {
  try {
    const { itemType, itemId, deliveryType, pickupLocation, dropoffLocation } = req.body;

    // Validate required fields
    if (!itemType || !['donation', 'request'].includes(itemType)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or missing itemType. Must be "donation" or "request"',
        errorCode: 'INVALID_ITEM_TYPE'
      });
    }

    if (!itemId) {
      return res.status(400).json({
        success: false,
        message: 'Item ID is required',
        errorCode: 'MISSING_ITEM_ID'
      });
    }

    if (!deliveryType || !['volunteer', 'paid'].includes(deliveryType)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or missing deliveryType. Must be "volunteer" or "paid"',
        errorCode: 'INVALID_DELIVERY_TYPE'
      });
    }

    // Validate locations
    if (!pickupLocation || !pickupLocation.coordinates) {
      return res.status(400).json({
        success: false,
        message: 'Pickup location with coordinates is required',
        errorCode: 'MISSING_PICKUP_LOCATION'
      });
    }

    if (!dropoffLocation || !dropoffLocation.coordinates) {
      return res.status(400).json({
        success: false,
        message: 'Dropoff location with coordinates is required',
        errorCode: 'MISSING_DROPOFF_LOCATION'
      });
    }

    // Check if item exists and is available for delivery
    let item;
    if (itemType === 'donation') {
      item = await require('../models/Donation').findById(itemId);
      if (!item) {
        return res.status(404).json({
          success: false,
          message: 'Donation not found',
          errorCode: 'ITEM_NOT_FOUND'
        });
      }
      if (item.status !== 'available') {
        return res.status(400).json({
          success: false,
          message: 'Donation is not available for delivery',
          errorCode: 'ITEM_NOT_AVAILABLE',
          currentStatus: item.status
        });
      }
    } else {
      item = await require('../models/Request').findById(itemId);
      if (!item) {
        return res.status(404).json({
          success: false,
          message: 'Request not found',
          errorCode: 'ITEM_NOT_FOUND'
        });
      }
      if (item.status !== 'active') {
        return res.status(400).json({
          success: false,
          message: 'Request is not active for delivery',
          errorCode: 'ITEM_NOT_AVAILABLE',
          currentStatus: item.status
        });
      }
    }

    // Check if delivery already exists for this item
    const existingDelivery = await Delivery.findOne({
      itemType,
      itemId,
      status: { $nin: ['cancelled', 'completed'] }
    });

    if (existingDelivery) {
      return res.status(409).json({
        success: false,
        message: 'A delivery request already exists for this item',
        errorCode: 'DELIVERY_ALREADY_EXISTS',
        existingDeliveryId: existingDelivery._id,
        existingStatus: existingDelivery.status
      });
    }

    req.item = item;
    next();

  } catch (error) {
    logger.error('Delivery creation validation error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during delivery creation validation',
      errorCode: 'VALIDATION_ERROR'
    });
  }
};

module.exports = {
  validateDeliveryAcceptance,
  validateDeliveryStatusUpdate,
  validatePayoutRequest,
  validateDeliveryCreation
};