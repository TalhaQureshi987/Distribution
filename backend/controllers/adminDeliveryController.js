const Delivery = require('../models/Delivery');
const Earning = require('../models/Earning');
const User = require('../models/User');
const logger = require('../config/logger');

// Get all deliveries with filtering and pagination
exports.getAllDeliveries = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      deliveryType,
      dateFrom,
      dateTo,
      search
    } = req.query;

    // Build filter query
    const filter = {};
    
    if (status) filter.status = status;
    if (deliveryType) filter.deliveryType = deliveryType;
    
    if (dateFrom || dateTo) {
      filter.createdAt = {};
      if (dateFrom) filter.createdAt.$gte = new Date(dateFrom);
      if (dateTo) filter.createdAt.$lte = new Date(dateTo);
    }

    // Search functionality
    if (search) {
      filter.$or = [
        { itemType: { $regex: search, $options: 'i' } },
        { 'pickupLocation.address': { $regex: search, $options: 'i' } },
        { 'deliveryLocation.address': { $regex: search, $options: 'i' } }
      ];
    }

    const skip = (page - 1) * limit;
    const totalDeliveries = await Delivery.countDocuments(filter);
    
    const deliveries = await Delivery.find(filter)
      .populate('deliveryPerson', 'name email phone')
      .populate('donor', 'name email phone')
      .populate('requester', 'name email phone')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Calculate statistics
    const stats = {
      total: totalDeliveries,
      pending: await Delivery.countDocuments({ ...filter, status: 'pending' }),
      accepted: await Delivery.countDocuments({ ...filter, status: 'accepted' }),
      in_progress: await Delivery.countDocuments({ ...filter, status: 'in_progress' }),
      completed: await Delivery.countDocuments({ ...filter, status: 'completed' }),
      cancelled: await Delivery.countDocuments({ ...filter, status: 'cancelled' })
    };

    res.json({
      deliveries,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(totalDeliveries / limit),
        limit: parseInt(limit),
        totalItems: totalDeliveries
      },
      stats
    });

  } catch (error) {
    logger.error('Error fetching deliveries:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get delivery analytics
exports.getDeliveryAnalytics = async (req, res) => {
  try {
    const { period = '30' } = req.query;
    const daysAgo = new Date();
    daysAgo.setDate(daysAgo.getDate() - parseInt(period));

    // Performance by delivery type
    const performanceByType = await Delivery.aggregate([
      { $match: { createdAt: { $gte: daysAgo } } },
      {
        $group: {
          _id: '$deliveryType',
          totalDeliveries: { $sum: 1 },
          completedDeliveries: {
            $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
          },
          totalEarnings: { $sum: '$totalEarning' }
        }
      },
      {
        $addFields: {
          completionRate: {
            $divide: ['$completedDeliveries', '$totalDeliveries']
          }
        }
      }
    ]);

    // Top delivery personnel
    const topDeliveryPersonnel = await Delivery.aggregate([
      { 
        $match: { 
          createdAt: { $gte: daysAgo },
          status: 'completed',
          deliveryPerson: { $exists: true }
        } 
      },
      {
        $group: {
          _id: '$deliveryPerson',
          completedDeliveries: { $sum: 1 },
          totalEarnings: { $sum: '$totalEarning' }
        }
      },
      {
        $lookup: {
          from: 'users',
          localField: '_id',
          foreignField: '_id',
          as: 'user'
        }
      },
      { $unwind: '$user' },
      {
        $project: {
          name: '$user.name',
          email: '$user.email',
          completedDeliveries: 1,
          totalEarnings: 1
        }
      },
      { $sort: { completedDeliveries: -1 } },
      { $limit: 10 }
    ]);

    // Earnings overview
    const earningsOverview = await Earning.aggregate([
      { $match: { createdAt: { $gte: daysAgo } } },
      {
        $group: {
          _id: null,
          totalEarnings: { $sum: '$totalAmount' },
          totalCommission: { $sum: '$commission' },
          totalNetEarnings: { $sum: '$netAmount' },
          pendingPayouts: {
            $sum: {
              $cond: [{ $eq: ['$status', 'requested'] }, '$netAmount', 0]
            }
          }
        }
      }
    ]);

    res.json({
      analytics: {
        performanceByType,
        topDeliveryPersonnel,
        earningsOverview: earningsOverview[0] || {
          totalEarnings: 0,
          totalCommission: 0,
          totalNetEarnings: 0,
          pendingPayouts: 0
        }
      }
    });

  } catch (error) {
    logger.error('Error fetching delivery analytics:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Admin force cancel delivery
exports.cancelDelivery = async (req, res) => {
  try {
    const { deliveryId } = req.params;
    const { reason } = req.body;
    const adminId = req.user.id;

    // Input validation
    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({ 
        message: 'Cancellation reason is required and must be at least 5 characters long' 
      });
    }

    const delivery = await Delivery.findById(deliveryId)
      .populate('deliveryPerson', 'name email phone')
      .populate('donor', 'name email phone')
      .populate('requester', 'name email phone');

    if (!delivery) {
      return res.status(404).json({ message: 'Delivery not found' });
    }

    if (['completed', 'cancelled'].includes(delivery.status)) {
      return res.status(400).json({ 
        message: 'Cannot cancel completed or already cancelled delivery' 
      });
    }

    const oldStatus = delivery.status;

    // Update delivery status
    delivery.status = 'cancelled';
    delivery.cancelledAt = new Date();
    delivery.cancelledBy = 'admin';
    delivery.cancellationReason = reason.trim();

    await delivery.save();

    // Create admin log
    logger.info(`Admin ${adminId} cancelled delivery ${deliveryId} with reason: ${reason}`);

    // Send notifications to involved parties
    const io = req.app.locals.io;
    
    if (delivery.deliveryPerson) {
      io.to(`user_${delivery.deliveryPerson._id}`).emit('deliveryCancelled', {
        deliveryId: delivery._id,
        reason: reason.trim(),
        message: `Delivery has been cancelled by admin. Reason: ${reason.trim()}`
      });
    }

    if (delivery.donor) {
      io.to(`user_${delivery.donor._id}`).emit('deliveryCancelled', {
        deliveryId: delivery._id,
        reason: reason.trim(),
        message: `Delivery has been cancelled by admin. Reason: ${reason.trim()}`
      });
    }

    if (delivery.requester) {
      io.to(`user_${delivery.requester._id}`).emit('deliveryCancelled', {
        deliveryId: delivery._id,
        reason: reason.trim(),
        message: `Delivery has been cancelled by admin. Reason: ${reason.trim()}`
      });
    }

    // Notify admins about delivery cancellation
    if (global.adminSocketManager) {
      global.adminSocketManager.notifyDeliveryCancelled(delivery, reason.trim(), 'admin');
    }

    res.json({
      message: 'Delivery cancelled successfully',
      delivery,
      reason: reason.trim()
    });

  } catch (error) {
    logger.error('Error cancelling delivery:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get all payout requests
exports.getAllPayoutRequests = async (req, res) => {
  try {
    const { page = 1, limit = 20, status = 'requested' } = req.query;

    const filter = { 'payoutRequest.status': status };
    const skip = (page - 1) * limit;
    
    const totalRequests = await Earning.countDocuments(filter);
    
    const payoutRequests = await Earning.find(filter)
      .populate('user', 'name email phone')
      .sort({ 'payoutRequest.requestedAt': -1 })
      .skip(skip)
      .limit(parseInt(limit));

    res.json({
      payoutRequests,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(totalRequests / limit),
        limit: parseInt(limit),
        totalItems: totalRequests
      }
    });

  } catch (error) {
    logger.error('Error fetching payout requests:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Approve payout request
exports.approvePayoutRequest = async (req, res) => {
  try {
    const { earningId } = req.params;
    const { transactionId } = req.body;
    const adminId = req.user.id;

    // Input validation
    if (!transactionId || transactionId.trim().length < 5) {
      return res.status(400).json({ 
        message: 'Transaction ID is required and must be at least 5 characters long' 
      });
    }

    const earning = await Earning.findById(earningId).populate('user', 'name email phone');
    
    if (!earning) {
      return res.status(404).json({ message: 'Earning record not found' });
    }

    if (earning.status !== 'requested') {
      return res.status(400).json({ 
        message: 'Payout request is not in requested status' 
      });
    }

    // Check if transaction ID already exists
    const existingTransaction = await Earning.findOne({
      'payoutRequest.transactionId': transactionId.trim(),
      _id: { $ne: earningId }
    });

    if (existingTransaction) {
      return res.status(400).json({ 
        message: 'Transaction ID already exists. Please use a unique transaction ID.' 
      });
    }

    const oldStatus = earning.status;

    // Update earning status
    earning.status = 'paid';
    earning.payoutRequest.status = 'approved';
    earning.payoutRequest.approvedAt = new Date();
    earning.payoutRequest.approvedBy = adminId;
    earning.payoutRequest.transactionId = transactionId.trim();

    await earning.save();

    // Create admin log
    logger.info(`Admin ${adminId} approved payout request ${earningId} with transaction ${transactionId}`);

    // Send notification to user
    const io = req.app.locals.io;
    io.to(`user_${earning.user._id}`).emit('payoutApproved', {
      earningId: earning._id,
      amount: earning.netAmount,
      transactionId: transactionId.trim(),
      message: 'Your payout request has been approved and processed'
    });

    // Notify admins about payout status change
    if (global.adminSocketManager) {
      global.adminSocketManager.notifyPayoutStatusChange(
        earning, 
        earning.user, 
        oldStatus, 
        'paid', 
        { type: 'approved', adminId, transactionId: transactionId.trim() }
      );
    }

    res.json({
      message: 'Payout request approved successfully',
      earning,
      transactionId: transactionId.trim()
    });

  } catch (error) {
    logger.error('Error approving payout request:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Reject payout request
exports.rejectPayoutRequest = async (req, res) => {
  try {
    const { earningId } = req.params;
    const { reason } = req.body;
    const adminId = req.user.id;

    // Input validation
    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({ 
        message: 'Rejection reason is required and must be at least 5 characters long' 
      });
    }

    const earning = await Earning.findById(earningId).populate('user', 'name email phone');
    
    if (!earning) {
      return res.status(404).json({ message: 'Earning record not found' });
    }

    if (earning.status !== 'requested') {
      return res.status(400).json({ 
        message: 'Payout request is not in requested status' 
      });
    }

    const oldStatus = earning.status;

    // Update earning status
    earning.status = 'completed'; // Return to completed status
    earning.payoutRequest.status = 'rejected';
    earning.payoutRequest.rejectedAt = new Date();
    earning.payoutRequest.rejectedBy = adminId;
    earning.payoutRequest.rejectionReason = reason.trim();

    await earning.save();

    // Update user's pending earnings (add back the rejected amount)
    const user = await User.findById(earning.user._id);
    user.pendingEarnings += earning.netAmount;
    await user.save();

    // Create admin log
    logger.info(`Admin ${adminId} rejected payout request ${earningId} with reason: ${reason}`);

    // Send notification to user
    const io = req.app.locals.io;
    io.to(`user_${earning.user._id}`).emit('payoutRejected', {
      earningId: earning._id,
      amount: earning.netAmount,
      reason: reason.trim(),
      message: `Your payout request has been rejected. Reason: ${reason.trim()}`
    });

    // Notify admins about payout status change
    if (global.adminSocketManager) {
      global.adminSocketManager.notifyPayoutStatusChange(
        earning, 
        earning.user, 
        oldStatus, 
        'rejected', 
        { type: 'rejected', adminId, reason: reason.trim() }
      );
    }

    res.json({
      message: 'Payout request rejected successfully',
      earning,
      reason: reason.trim()
    });

  } catch (error) {
    logger.error('Error rejecting payout request:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get delivery personnel management data
exports.getDeliveryPersonnel = async (req, res) => {
  try {
    const { page = 1, limit = 20, status } = req.query;

    // Build filter for users with delivery experience
    const deliveryPersonIds = await Delivery.distinct('deliveryPerson', {
      deliveryPerson: { $exists: true }
    });

    const filter = { 
      _id: { $in: deliveryPersonIds },
      role: { $in: ['volunteer', 'delivery_person'] }
    };

    if (status) filter.status = status;

    const skip = (page - 1) * limit;
    const totalPersonnel = await User.countDocuments(filter);

    const personnel = await User.find(filter)
      .select('name email phone status totalEarnings pendingEarnings createdAt')
      .sort({ totalEarnings: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Get delivery stats for each person
    const personnelWithStats = await Promise.all(
      personnel.map(async (person) => {
        const deliveryStats = await Delivery.aggregate([
          { $match: { deliveryPerson: person._id } },
          {
            $group: {
              _id: null,
              totalDeliveries: { $sum: 1 },
              completedDeliveries: {
                $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
              },
              activeDeliveries: {
                $sum: { 
                  $cond: [
                    { $in: ['$status', ['accepted', 'in_progress']] }, 
                    1, 
                    0
                  ] 
                }
              }
            }
          }
        ]);

        return {
          ...person.toObject(),
          deliveryStats: deliveryStats[0] || {
            totalDeliveries: 0,
            completedDeliveries: 0,
            activeDeliveries: 0
          }
        };
      })
    );

    res.json({
      personnel: personnelWithStats,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(totalPersonnel / limit),
        limit: parseInt(limit),
        totalItems: totalPersonnel
      }
    });

  } catch (error) {
    logger.error('Error fetching delivery personnel:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};