const Payment = require('../models/Payment');
const User = require('../models/User');
const Delivery = require('../models/Delivery');
const Request = require('../models/Request');
const Donation = require('../models/Donation');

// Revenue Analytics for Admin
const getRevenueAnalytics = async (req, res) => {
  try {
    const { startDate, endDate, role, userId } = req.query;
    
    // Build date filter
    let dateFilter = {};
    if (startDate && endDate) {
      dateFilter = {
        createdAt: {
          $gte: new Date(startDate),
          $lte: new Date(endDate)
        }
      };
    }

    // Build user filter
    let userFilter = {};
    if (role && role !== 'All') {
      const users = await User.find({ role: role.toLowerCase() });
      userFilter.userId = { $in: users.map(u => u._id) };
    }
    if (userId && userId !== 'All') {
      userFilter.userId = userId;
    }

    const filter = { ...dateFilter, ...userFilter };

    // Calculate revenue stats
    const [
      registrationFees,
      requestFees,
      deliveryCharges,
      deliveryCommissions
    ] = await Promise.all([
      // Registration Fees
      Payment.aggregate([
        { $match: { ...filter, type: 'registration_fee' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]),
      
      // Request Fees (100 PKR each)
      Payment.aggregate([
        { $match: { ...filter, type: 'request_fee' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]),
      
      // Delivery Charges
      Payment.aggregate([
        { $match: { ...filter, type: 'delivery_charge' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]),
      
      // Delivery Commissions
      Payment.aggregate([
        { $match: { ...filter, type: 'delivery_commission' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ])
    ]);

    const stats = {
      registrationFees: registrationFees[0]?.total || 0,
      requestFees: requestFees[0]?.total || 0,
      deliveryCharges: deliveryCharges[0]?.total || 0,
      deliveryCommissions: deliveryCommissions[0]?.total || 0,
    };

    stats.totalRevenue = stats.registrationFees + stats.requestFees + 
                        stats.deliveryCharges + stats.deliveryCommissions;

    // Get monthly breakdown
    const monthlyRevenue = await Payment.aggregate([
      { $match: filter },
      {
        $group: {
          _id: {
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' },
            type: '$type'
          },
          total: { $sum: '$amount' }
        }
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } }
    ]);

    res.json({
      success: true,
      stats,
      monthlyRevenue
    });

  } catch (error) {
    console.error('Error getting revenue analytics:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting revenue analytics'
    });
  }
};

// Get Delivery Payments for Admin
const getDeliveryPayments = async (req, res) => {
  try {
    const deliveryPayments = await Payment.find({
      type: { $in: ['delivery_charge', 'delivery_commission'] }
    })
    .populate('userId', 'name email phone role')
    .populate('deliveryId')
    .sort({ createdAt: -1 })
    .limit(100);

    const formattedPayments = await Promise.all(
      deliveryPayments.map(async (payment) => {
        let deliveryDetails = {};
        
        if (payment.deliveryId) {
          const delivery = await Delivery.findById(payment.deliveryId)
            .populate('itemId')
            .populate('donor', 'name')
            .populate('requester', 'name');
          
          deliveryDetails = {
            distance: delivery.distance || 0,
            pickupLocation: delivery.pickupLocation,
            deliveryLocation: delivery.deliveryLocation,
            itemTitle: delivery.itemId?.title || 'N/A',
            donorName: delivery.donor?.name || 'N/A',
            requesterName: delivery.requester?.name || 'N/A'
          };
        }

        return {
          id: payment._id,
          userId: payment.userId._id,
          userName: payment.userId.name,
          userEmail: payment.userId.email,
          userPhone: payment.userId.phone,
          userRole: payment.userId.role,
          type: payment.type,
          amount: payment.amount,
          status: payment.status,
          createdAt: payment.createdAt,
          ...deliveryDetails
        };
      })
    );

    res.json({
      success: true,
      payments: formattedPayments
    });

  } catch (error) {
    console.error('Error getting delivery payments:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting delivery payments'
    });
  }
};

// Get Company Payments for Admin
const getCompanyPayments = async (req, res) => {
  try {
    const companyPayments = await Payment.find({
      type: { $in: ['registration_fee', 'request_fee', 'delivery_commission'] }
    })
    .populate('userId', 'name email phone role')
    .sort({ createdAt: -1 })
    .limit(100);

    const formattedPayments = companyPayments.map(payment => ({
      id: payment._id,
      userId: payment.userId._id,
      userName: payment.userId.name,
      userEmail: payment.userId.email,
      userPhone: payment.userId.phone,
      userRole: payment.userId.role,
      type: payment.type,
      amount: payment.amount,
      status: payment.status,
      description: payment.description,
      createdAt: payment.createdAt
    }));

    res.json({
      success: true,
      payments: formattedPayments
    });

  } catch (error) {
    console.error('Error getting company payments:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting company payments'
    });
  }
};

// Get Role-Based Payments for Admin
const getRoleBasedPayments = async (req, res) => {
  try {
    const { role } = req.query;
    
    let userFilter = {};
    if (role && role !== 'All') {
      const users = await User.find({ role: role.toLowerCase() });
      userFilter = { userId: { $in: users.map(u => u._id) } };
    }

    const payments = await Payment.find(userFilter)
      .populate('userId', 'name email phone role')
      .sort({ createdAt: -1 })
      .limit(100);

    const formattedPayments = payments.map(payment => ({
      id: payment._id,
      userId: payment.userId._id,
      userName: payment.userId.name,
      userEmail: payment.userId.email,
      userPhone: payment.userId.phone,
      userRole: payment.userId.role,
      type: payment.type,
      amount: payment.amount,
      status: payment.status,
      description: payment.description,
      createdAt: payment.createdAt
    }));

    res.json({
      success: true,
      payments: formattedPayments
    });

  } catch (error) {
    console.error('Error getting role-based payments:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting role-based payments'
    });
  }
};

// Get User Payments (for Profile Screen)
const getUserPayments = async (req, res) => {
  try {
    const userId = req.user._id;
    const userRole = req.user.role;

    let paymentTypes = [];
    
    // Define payment types based on user role
    switch (userRole) {
      case 'delivery':
        paymentTypes = ['registration_fee', 'delivery_charge', 'delivery_commission'];
        break;
      case 'requester':
        paymentTypes = ['registration_fee', 'request_fee'];
        break;
      case 'donor':
        paymentTypes = ['registration_fee', 'delivery_charge'];
        break;
      case 'volunteer':
        // Volunteers don't have payments
        return res.json({
          success: true,
          payments: [],
          message: 'Volunteers do not have payment records'
        });
      default:
        paymentTypes = ['registration_fee'];
    }

    const payments = await Payment.find({
      userId: userId,
      type: { $in: paymentTypes }
    })
    .populate('deliveryId')
    .sort({ createdAt: -1 });

    const formattedPayments = await Promise.all(
      payments.map(async (payment) => {
        let additionalInfo = {};
        
        if (payment.type === 'delivery_charge' || payment.type === 'delivery_commission') {
          if (payment.deliveryId) {
            const delivery = await Delivery.findById(payment.deliveryId)
              .populate('itemId', 'title');
            
            additionalInfo = {
              distance: delivery.distance || 0,
              itemTitle: delivery.itemId?.title || 'N/A',
              pickupLocation: delivery.pickupLocation,
              deliveryLocation: delivery.deliveryLocation
            };
          }
        }

        return {
          id: payment._id,
          type: payment.type,
          amount: payment.amount,
          status: payment.status,
          description: payment.description,
          createdAt: payment.createdAt,
          ...additionalInfo
        };
      })
    );

    res.json({
      success: true,
      payments: formattedPayments,
      userRole: userRole
    });

  } catch (error) {
    console.error('Error getting user payments:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting user payments'
    });
  }
};

module.exports = {
  getRevenueAnalytics,
  getDeliveryPayments,
  getCompanyPayments,
  getRoleBasedPayments,
  getUserPayments
};
