const { logger } = require('../utils/logger');

class AdminSocketManager {
  constructor() {
    this.io = null;
    this.adminSockets = new Map(); // Map of admin socket IDs to user info
  }

  initialize(io) {
    this.io = io;
    logger.info('Admin Socket Manager initialized');
    
    // Set up admin-specific namespace or handle admin connections
    this.setupAdminHandlers();
  }

  setupAdminHandlers() {
    if (!this.io) return;

    // Handle admin connections in the main namespace
    this.io.on('connection', (socket) => {
      // Check if user is admin (this would be set during authentication)
      if (socket.user && socket.user.role === 'admin') {
        this.handleAdminConnection(socket);
      }
    });
  }

  handleAdminConnection(socket) {
    const adminId = socket.user.id;
    const adminName = socket.user.name;

    // Store admin socket
    this.adminSockets.set(socket.id, {
      userId: adminId,
      userName: adminName,
      connectedAt: new Date()
    });

    // Join admin room
    socket.join('admin_room');
    
    logger.info('Admin Connected', {
      adminId,
      adminName,
      socketId: socket.id
    });

    // Handle admin disconnect
    socket.on('disconnect', () => {
      this.adminSockets.delete(socket.id);
      logger.info('Admin Disconnected', {
        adminId,
        socketId: socket.id
      });
    });
  }

  // Notify all admins about delivery events
  notifyDeliveryStatusChange(delivery, oldStatus, newStatus, metadata = {}) {
    if (!this.io) return;

    const notification = {
      type: 'delivery_status_change',
      deliveryId: delivery._id,
      oldStatus,
      newStatus,
      delivery: {
        id: delivery._id,
        itemType: delivery.itemType,
        status: delivery.status,
        deliveryPerson: delivery.deliveryPerson,
        pickupAddress: delivery.pickupLocation?.address,
        deliveryAddress: delivery.deliveryLocation?.address
      },
      timestamp: new Date(),
      metadata
    };

    this.io.to('admin_room').emit('deliveryStatusUpdate', notification);
    
    logger.info('Admin Notification - Delivery Status Change', {
      deliveryId: delivery._id,
      oldStatus,
      newStatus,
      adminCount: this.adminSockets.size
    });
  }

  // Notify admins about delivery cancellation
  notifyDeliveryCancelled(delivery, reason, cancelledBy) {
    if (!this.io) return;

    const notification = {
      type: 'delivery_cancelled',
      deliveryId: delivery._id,
      reason,
      cancelledBy,
      delivery: {
        id: delivery._id,
        itemType: delivery.itemType,
        status: delivery.status,
        deliveryPerson: delivery.deliveryPerson,
        pickupAddress: delivery.pickupLocation?.address,
        deliveryAddress: delivery.deliveryLocation?.address
      },
      timestamp: new Date()
    };

    this.io.to('admin_room').emit('deliveryCancelled', notification);
    
    logger.info('Admin Notification - Delivery Cancelled', {
      deliveryId: delivery._id,
      reason,
      cancelledBy,
      adminCount: this.adminSockets.size
    });
  }

  // Notify admins about payout status changes
  notifyPayoutStatusChange(earning, user, oldStatus, newStatus, metadata = {}) {
    if (!this.io) return;

    const notification = {
      type: 'payout_status_change',
      earningId: earning._id,
      userId: user._id,
      userName: user.name,
      oldStatus,
      newStatus,
      amount: earning.netAmount,
      earning: {
        id: earning._id,
        totalAmount: earning.totalAmount,
        netAmount: earning.netAmount,
        status: earning.status
      },
      timestamp: new Date(),
      metadata
    };

    this.io.to('admin_room').emit('payoutStatusUpdate', notification);
    
    logger.info('Admin Notification - Payout Status Change', {
      earningId: earning._id,
      userId: user._id,
      oldStatus,
      newStatus,
      amount: earning.netAmount,
      adminCount: this.adminSockets.size
    });
  }

  // Notify admins about new payout requests
  notifyNewPayoutRequest(earning, user) {
    if (!this.io) return;

    const notification = {
      type: 'new_payout_request',
      earningId: earning._id,
      userId: user._id,
      userName: user.name,
      amount: earning.netAmount,
      requestedAt: earning.payoutRequest.requestedAt,
      earning: {
        id: earning._id,
        totalAmount: earning.totalAmount,
        netAmount: earning.netAmount,
        status: earning.status
      },
      timestamp: new Date()
    };

    this.io.to('admin_room').emit('newPayoutRequest', notification);
    
    logger.info('Admin Notification - New Payout Request', {
      earningId: earning._id,
      userId: user._id,
      amount: earning.netAmount,
      adminCount: this.adminSockets.size
    });
  }

  // Get connected admin count
  getConnectedAdminCount() {
    return this.adminSockets.size;
  }

  // Get admin statistics
  getAdminStats() {
    return {
      connectedAdmins: this.adminSockets.size,
      adminSockets: Array.from(this.adminSockets.values())
    };
  }
}

// Create singleton instance
const adminSocketManager = new AdminSocketManager();

module.exports = adminSocketManager;