const Request = require('../models/Request');
const User = require('../models/User');
const { getAdminSocketManager } = require('../logic/adminSocket');
const { getIO } = require('../logic/socket');

// Get all pending requests for verification
const getPendingRequests = async (req, res) => {
  try {
    console.log('🔍 Admin fetching pending requests...');
    console.log('🔍 Query params:', req.query);

    const { page = 1, limit = 10, type, priority } = req.query;

    const filter = {
      status: 'pending_verification',
      verificationStatus: { $in: ['pending', null] }
    };

    if (type) filter.requestType = type;
    if (priority) filter.priority = priority;

    console.log('🔍 Filter applied:', JSON.stringify(filter, null, 2));

    // First, let's check total requests in database
    const totalAllRequests = await Request.countDocuments({});
    console.log(`🔍 Total requests in database: ${totalAllRequests}`);

    // Check requests by status
    const statusCounts = await Request.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } }
    ]);
    console.log('🔍 Requests by status:', statusCounts);

    // Check requests by verification status
    const verificationCounts = await Request.aggregate([
      { $group: { _id: "$verificationStatus", count: { $sum: 1 } } }
    ]);
    console.log('🔍 Requests by verification status:', verificationCounts);

    const requests = await Request.find(filter)
      .populate('userId', 'name email phone')
      .sort({ createdAt: -1, priority: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Request.countDocuments(filter);

    console.log(`🔍 Found ${total} pending requests matching filter`);
    console.log(`🔍 Returning ${requests.length} requests for page ${page}`);

    res.json({
      success: true,
      requests,
      pagination: {
        current: page,
        pages: Math.ceil(total / limit),
        total
      }
    });
  } catch (error) {
    console.error('❌ Error fetching pending requests:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get request verification history
const getRequestHistory = async (req, res) => {
  try {
    const { page = 1, limit = 10, status, type } = req.query;

    const filter = {
      verificationStatus: { $in: ['verified', 'rejected'] }
    };

    if (status) filter.verificationStatus = status;
    if (type) filter.requestType = type;

    const requests = await Request.find(filter)
      .populate('userId', 'name email phone')
      .populate('verifiedBy', 'name email')
      .sort({ verificationDate: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Request.countDocuments(filter);

    res.json({
      success: true,
      requests,
      pagination: {
        current: page,
        pages: Math.ceil(total / limit),
        total
      }
    });
  } catch (error) {
    console.error('Error fetching request history:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Verify a request
const verifyRequest = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { notes } = req.body;

    // Input validation
    if (!notes || notes.trim().length < 5) {
      return res.status(400).json({
        message: 'Verification notes are required and must be at least 5 characters long'
      });
    }

    const request = await Request.findById(requestId).populate('userId', 'name email');

    if (!request) {
      return res.status(404).json({ message: 'Request not found' });
    }

    if (request.verificationStatus === 'verified') {
      return res.status(400).json({ message: 'Request is already verified' });
    }

    if (request.verificationStatus === 'rejected') {
      return res.status(400).json({ message: 'Request is already rejected' });
    }

    // Update request
    request.verificationStatus = 'verified';
    request.status = 'approved';
    request.verificationNotes = notes.trim();
    request.verifiedBy = req.user.id;
    request.verificationDate = new Date();

    await request.save();

    // Send real-time notification to the user who created the request
    try {
      const io = getIO();

      if (io) {
        const roomName = `user_${request.userId._id}`;
        console.log(`🔔 Sending request verification notification to room: ${roomName}`);

        const notificationData = {
          type: 'request_verified',
          title: '🎉 Request Verified!',
          message: `Your ${request.requestType} request has been verified and approved!`,
          requestId: request._id,
          requestType: request.requestType,
          verificationNotes: notes.trim(),
          verifiedBy: req.user.name,
          timestamp: new Date().toISOString(),
          request: {
            id: request._id,
            title: request.title || `${request.requestType} Request`,
            verificationStatus: request.verificationStatus,
            verifiedAt: request.verificationDate
          }
        };

        console.log(`🎯 SOCKET: Notification data:`, JSON.stringify(notificationData, null, 2));

        // Primary event emission to user room
        io.to(roomName).emit('request_verification_update', notificationData);

        // Fallback direct socket emission
        io.sockets.sockets.forEach((socket) => {
          if (socket.userId === request.userId._id.toString()) {
            console.log(`🎯 SOCKET: Direct emit to socket ${socket.id} for user ${socket.userId}`);
            socket.emit('request_verification_update', notificationData);
          }
        });

        console.log(`✅ Request verification notification sent to user_${request.userId._id}`);
        console.log(`📡 Event sent: request_verification_update`);
      } else {
        console.log('❌ Socket.IO instance not available for request verification');
      }
    } catch (socketError) {
      console.error('❌ Socket error in request verification:', socketError);
    }

    // Send real-time notification to admins
    const adminSocketManager = getAdminSocketManager();
    if (adminSocketManager) {
      adminSocketManager.notifyAdmins('requestVerified', {
        requestId: request._id,
        requestType: request.requestType,
        userId: request.userId._id,
        userName: request.userId.name,
        verifiedBy: req.user.name,
        notes: notes.trim(),
        timestamp: new Date()
      });
    }

    // Log the action
    console.log(`Request ${requestId} verified by admin ${req.user.name} (${req.user.id})`);

    res.json({
      success: true,
      message: 'Request verified successfully',
      request: {
        ...request.toObject(),
        verifiedBy: { name: req.user.name, email: req.user.email }
      }
    });
  } catch (error) {
    console.error('Error verifying request:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Reject a request
const rejectRequest = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { reason } = req.body;

    // Input validation
    if (!reason || reason.trim().length < 10) {
      return res.status(400).json({
        message: 'Rejection reason is required and must be at least 10 characters long'
      });
    }

    const request = await Request.findById(requestId).populate('userId', 'name email');

    if (!request) {
      return res.status(404).json({ message: 'Request not found' });
    }

    if (request.verificationStatus === 'verified') {
      return res.status(400).json({ message: 'Cannot reject a verified request' });
    }

    if (request.verificationStatus === 'rejected') {
      return res.status(400).json({ message: 'Request is already rejected' });
    }

    // Update request
    request.verificationStatus = 'rejected';
    request.status = 'rejected';
    request.rejectionReason = reason.trim();
    request.verifiedBy = req.user.id;
    request.verificationDate = new Date();

    await request.save();

    // Send real-time notification to the user who created the request
    try {
      const io = getIO();

      if (io) {
        const roomName = `user_${request.userId._id}`;
        console.log(`🔔 Sending request rejection notification to room: ${roomName}`);

        const notificationData = {
          type: 'request_rejected',
          title: '🚫 Request Rejected!',
          message: `Your ${request.requestType} request has been rejected.`,
          requestId: request._id,
          requestType: request.requestType,
          rejectionReason: reason.trim(),
          rejectedBy: req.user.name,
          timestamp: new Date().toISOString(),
          request: {
            id: request._id,
            title: request.title || `${request.requestType} Request`,
            verificationStatus: request.verificationStatus,
            rejectedAt: request.verificationDate
          }
        };

        console.log(`🎯 SOCKET: Notification data:`, JSON.stringify(notificationData, null, 2));

        // Primary event emission to user room
        io.to(roomName).emit('request_rejection_update', notificationData);

        // Fallback direct socket emission
        io.sockets.sockets.forEach((socket) => {
          if (socket.userId === request.userId._id.toString()) {
            console.log(`🎯 SOCKET: Direct emit to socket ${socket.id} for user ${socket.userId}`);
            socket.emit('request_rejection_update', notificationData);
          }
        });

        console.log(`✅ Request rejection notification sent to user_${request.userId._id}`);
        console.log(`📡 Event sent: request_rejection_update`);
      } else {
        console.log('❌ Socket.IO instance not available for request rejection');
      }
    } catch (socketError) {
      console.error('❌ Socket error in request rejection:', socketError);
    }

    // Send real-time notification to admins
    const adminSocketManager = getAdminSocketManager();
    if (adminSocketManager) {
      adminSocketManager.notifyAdmins('requestRejected', {
        requestId: request._id,
        requestType: request.requestType,
        userId: request.userId._id,
        userName: request.userId.name,
        rejectedBy: req.user.name,
        reason: reason.trim(),
        timestamp: new Date()
      });
    }

    // Log the action
    console.log(`Request ${requestId} rejected by admin ${req.user.name} (${req.user.id})`);

    res.json({
      success: true,
      message: 'Request rejected successfully',
      request: {
        ...request.toObject(),
        verifiedBy: { name: req.user.name, email: req.user.email }
      }
    });
  } catch (error) {
    console.error('Error rejecting request:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Get request statistics
const getRequestStats = async (req, res) => {
  try {
    const stats = await Request.aggregate([
      {
        $group: {
          _id: '$verificationStatus',
          count: { $sum: 1 }
        }
      }
    ]);

    const typeStats = await Request.aggregate([
      {
        $group: {
          _id: '$requestType',
          count: { $sum: 1 }
        }
      }
    ]);

    const priorityStats = await Request.aggregate([
      {
        $group: {
          _id: '$priority',
          count: { $sum: 1 }
        }
      }
    ]);

    const formattedStats = {
      byStatus: stats.reduce((acc, stat) => {
        acc[stat._id || 'pending'] = stat.count;
        return acc;
      }, {}),
      byType: typeStats.reduce((acc, stat) => {
        acc[stat._id] = stat.count;
        return acc;
      }, {}),
      byPriority: priorityStats.reduce((acc, stat) => {
        acc[stat._id] = stat.count;
        return acc;
      }, {})
    };

    res.json({
      success: true,
      stats: formattedStats
    });
  } catch (error) {
    console.error('Error fetching request stats:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getPendingRequests,
  getRequestHistory,
  verifyRequest,
  rejectRequest,
  getRequestStats
};
