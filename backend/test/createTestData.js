const mongoose = require('mongoose');
const Donation = require('../models/Donation');
const Request = require('../models/Request');

// Connect to MongoDB
const connectDB = async () => {
  try {
    await mongoose.connect(
      process.env.MONGO_URI ||
        'mongodb+srv://talhaabid400_db_user:talhaqureshi@cluster0.q5oqr9j.mongodb.net/zerofoodwaste'
    );
    console.log('✅ MongoDB Connected for testing');
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error);
    process.exit(1);
  }
};

// Create test donations with different delivery options
const createTestDonations = async (userId = '68cbbd907670affb64d66e54') => {
  try {
    console.log('🧪 Creating test donations...');

    // Test Donation 1: Paid Delivery
    const paidDeliveryDonation = new Donation({
      donorId: userId,
      donorName: 'Test Donor',
      title: 'Test Paid Delivery Food',
      description:
        'Test donation with PAID DELIVERY option for notifications testing',
      foodType: 'Food',
      foodCategory: 'Prepared Meals', // ✅ fixed to match enum
      foodName: 'Test Cooked Meals',
      quantity: 10,
      quantityUnit: 'kg',
      expiryDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      pickupAddress: 'Test Location for Paid Delivery, Karachi, Pakistan',
      latitude: 24.87,
      longitude: 67.03,
      location: {
        type: 'Point',
        coordinates: [67.03, 24.87],
      },
      deliveryOption: 'Paid Delivery',
      paymentAmount: 120,
      deliveryDistance: 5.2,
      isUrgent: false,
      images: [],
      verificationStatus: 'pending',
      status: 'available',
    });

    // Test Donation 2: Volunteer Delivery
    const volunteerDeliveryDonation = new Donation({
      donorId: userId,
      donorName: 'Test Donor',
      title: 'Test Volunteer Delivery Food',
      description:
        'Test donation with VOLUNTEER DELIVERY option for notifications testing',
      foodType: 'Food',
      foodCategory: 'Fruits & Vegetables', // ✅ fixed to match enum
      foodName: 'Test Fresh Vegetables',
      quantity: 8,
      quantityUnit: 'kg',
      expiryDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      pickupAddress: 'Test Location for Volunteer Delivery, Karachi, Pakistan',
      latitude: 24.85,
      longitude: 67.02,
      location: {
        type: 'Point',
        coordinates: [67.02, 24.85],
      },
      deliveryOption: 'Volunteer Delivery',
      paymentAmount: 0,
      deliveryDistance: 3.8,
      isUrgent: true,
      images: [],
      verificationStatus: 'pending',
      status: 'available',
    });

    const savedPaid = await paidDeliveryDonation.save();
    const savedVolunteer = await volunteerDeliveryDonation.save();

    console.log('✅ Test donations created:');
    console.log(
      `📦 Paid Delivery: ${savedPaid._id} - "${savedPaid.deliveryOption}"`
    );
    console.log(
      `📦 Volunteer Delivery: ${savedVolunteer._id} - "${savedVolunteer.deliveryOption}"`
    );

    return [savedPaid, savedVolunteer];
  } catch (error) {
    console.error('❌ Error creating test donations:', error);
    throw error;
  }
};

// Create test requests with different delivery options
const createTestRequests = async (userId = '68cbbd907670affb64d66e54') => {
  try {
    console.log('🧪 Creating test requests...');

    // Test Request 1: Paid Delivery
    const paidDeliveryRequest = new Request({
      requesterId: userId,
      title: 'Test Paid Delivery Request',
      description:
        'Test request with PAID DELIVERY option for notifications testing',
      itemType: 'Food',
      category: 'Prepared Meals', // ✅ aligned with donation schema
      quantity: 5,
      quantityUnit: 'kg',
      urgency: 'medium',
      neededBy: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      location: 'Test Location for Paid Request, Karachi, Pakistan',
      latitude: 24.86,
      longitude: 67.025,
      contactInfo: 'test@example.com',
      metadata: {
        deliveryOption: 'Paid Delivery',
        paymentAmount: 100,
        deliveryDistance: 4.5,
      },
      images: [],
      verificationStatus: 'pending',
      status: 'active',
    });

    // Test Request 2: Volunteer Delivery
    const volunteerDeliveryRequest = new Request({
      requesterId: userId,
      title: 'Test Volunteer Delivery Request',
      description:
        'Test request with VOLUNTEER DELIVERY option for notifications testing',
      itemType: 'Medicine',
      category: 'Other', // ✅ fallback if "Basic Medicine" is not in enum
      quantity: 2,
      quantityUnit: 'boxes',
      urgency: 'high',
      neededBy: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000),
      location: 'Test Location for Volunteer Request, Karachi, Pakistan',
      latitude: 24.84,
      longitude: 67.015,
      contactInfo: 'test2@example.com',
      metadata: {
        deliveryOption: 'Volunteer Delivery',
        paymentAmount: 0,
        deliveryDistance: 2.8,
      },
      images: [],
      verificationStatus: 'pending',
      status: 'active',
    });

    const savedPaidRequest = await paidDeliveryRequest.save();
    const savedVolunteerRequest = await volunteerDeliveryRequest.save();

    console.log('✅ Test requests created:');
    console.log(
      `📋 Paid Delivery: ${savedPaidRequest._id} - "${savedPaidRequest.metadata.deliveryOption}"`
    );
    console.log(
      `📋 Volunteer Delivery: ${savedVolunteerRequest._id} - "${savedVolunteerRequest.metadata.deliveryOption}"`
    );

    return [savedPaidRequest, savedVolunteerRequest];
  } catch (error) {
    console.error('❌ Error creating test requests:', error);
    throw error;
  }
};

// Main function to create all test data
const createAllTestData = async () => {
  try {
    await connectDB();

    console.log('🚀 Creating test data for delivery notifications...\n');

    const donations = await createTestDonations();
    const requests = await createTestRequests();

    console.log('\n🎉 ALL TEST DATA CREATED SUCCESSFULLY!');
    console.log('\n📋 NEXT STEPS:');
    console.log('1. Go to admin panel → Donation Verification');
    console.log('2. Go to admin panel → Request Approval');
    console.log('3. Verify/approve the test items');
    console.log('4. Check "Deliver & Earn" screen for paid deliveries');
    console.log('5. Check logs for "🚚 Notifying delivery personnel" messages');

    console.log('\n🧪 TEST API ENDPOINTS:');
    console.log('GET /api/donations/paid-deliveries');
    console.log('GET /api/donations/volunteer-deliveries');
    console.log('GET /api/requests/paid-deliveries');
    console.log('GET /api/requests/volunteer-deliveries');

    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to create test data:', error);
    process.exit(1);
  }
};

// Run if called directly
if (require.main === module) {
  createAllTestData();
}

module.exports = {
  createTestDonations,
  createTestRequests,
  createAllTestData,
};
