const mongoose = require('mongoose');
const Donation = require('../models/Donation');
const Request = require('../models/Request');

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/zerofoodwaste');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const verifyDeliveryOptions = async () => {
    await connectDB();

    try {
        console.log('🔍 Testing API endpoint field selection...\n');

        // Test 1: Check current getPendingDonations query (WITHOUT deliveryOption)
        console.log('📦 Testing CURRENT getPendingDonations query (missing deliveryOption):');
        const currentPendingDonations = await Donation.find({
            verificationStatus: 'pending'
        })
            .sort({ createdAt: -1 })
            .populate('donorId', 'name email phone')
            .select('title description foodType quantity verificationStatus createdAt donorId pickupAddress images');

        console.log(`Found ${currentPendingDonations.length} pending donations with CURRENT query:`);
        currentPendingDonations.forEach(donation => {
            console.log(`  - "${donation.title}"`);
            console.log(`    Delivery Option: "${donation.deliveryOption}" (${typeof donation.deliveryOption})`);
            console.log(`    Has deliveryOption field: ${donation.deliveryOption !== undefined}`);
            console.log('');
        });

        // Test 2: Check FIXED getPendingDonations query (WITH deliveryOption)
        console.log('📦 Testing FIXED getPendingDonations query (with deliveryOption):');
        const fixedPendingDonations = await Donation.find({
            verificationStatus: 'pending'
        })
            .sort({ createdAt: -1 })
            .populate('donorId', 'name email phone')
            .select('title description foodType quantity verificationStatus createdAt donorId pickupAddress images deliveryOption paymentAmount deliveryDistance');

        console.log(`Found ${fixedPendingDonations.length} pending donations with FIXED query:`);
        fixedPendingDonations.forEach(donation => {
            console.log(`  - "${donation.title}"`);
            console.log(`    Delivery Option: "${donation.deliveryOption}" (${typeof donation.deliveryOption})`);
            console.log(`    Payment Amount: ${donation.paymentAmount || 'N/A'}`);
            console.log(`    Has deliveryOption field: ${donation.deliveryOption !== undefined}`);
            console.log('');
        });

        // Test 3: Check raw database data
        console.log('🔍 Testing raw database data:');
        const rawDonations = await Donation.find({
            title: { $regex: /Test.*Delivery/i }
        }).select('title deliveryOption paymentAmount verificationStatus');

        console.log(`Found ${rawDonations.length} test donations in database:`);
        rawDonations.forEach(donation => {
            console.log(`  - "${donation.title}"`);
            console.log(`    Raw deliveryOption: "${donation.deliveryOption}"`);
            console.log(`    Type: ${typeof donation.deliveryOption}`);
            console.log(`    Payment Amount: ${donation.paymentAmount || 'N/A'}`);
            console.log(`    Status: ${donation.verificationStatus}`);
            console.log('');
        });

        // Test 4: Check requests with metadata
        console.log('📋 Testing requests with metadata:');
        const testRequests = await Request.find({
            title: { $regex: /Test.*Delivery/i }
        }).select('title metadata verificationStatus');

        console.log(`Found ${testRequests.length} test requests:`);
        testRequests.forEach(request => {
            console.log(`  - "${request.title}"`);
            console.log(`    Delivery Option: "${request.metadata?.deliveryOption}"`);
            console.log(`    Payment Amount: ${request.metadata?.paymentAmount || 'N/A'}`);
            console.log(`    Status: ${request.verificationStatus}`);
            console.log(`    Full metadata:`, JSON.stringify(request.metadata, null, 2));
            console.log('');
        });

        // Test 5: Simulate admin panel data structure
        console.log('🖥️ Simulating admin panel data:');
        console.log('BEFORE fixes (current query):');
        const adminDonationsBefore = currentPendingDonations.map(donation => ({
            title: donation.title,
            displayValue: donation.deliveryOption || 'Self delivery', // This is what admin panel shows
            actualValue: donation.deliveryOption,
            isUndefined: donation.deliveryOption === undefined,
            isNull: donation.deliveryOption === null,
            isEmpty: donation.deliveryOption === ''
        }));

        adminDonationsBefore.forEach(item => {
            console.log(`  - "${item.title}"`);
            console.log(`    Admin Panel Shows: "${item.displayValue}"`);
            console.log(`    Actual Value: "${item.actualValue}"`);
            console.log(`    Issues: undefined=${item.isUndefined}, null=${item.isNull}, empty=${item.isEmpty}`);
            console.log('');
        });

        console.log('AFTER fixes (fixed query):');
        const adminDonationsAfter = fixedPendingDonations.map(donation => ({
            title: donation.title,
            displayValue: donation.deliveryOption || 'Self delivery', // This is what admin panel shows
            actualValue: donation.deliveryOption,
            isUndefined: donation.deliveryOption === undefined,
            isNull: donation.deliveryOption === null,
            isEmpty: donation.deliveryOption === ''
        }));

        adminDonationsAfter.forEach(item => {
            console.log(`  - "${item.title}"`);
            console.log(`    Admin Panel Shows: "${item.displayValue}"`);
            console.log(`    Actual Value: "${item.actualValue}"`);
            console.log(`    Issues: undefined=${item.isUndefined}, null=${item.isNull}, empty=${item.isEmpty}`);
            console.log('');
        });

        // Test 6: Request validation test
        console.log('🧪 Testing request validation:');
        try {
            const testRequest = new Request({
                userId: new mongoose.Types.ObjectId(),
                requestType: 'food_request',
                title: 'Test Invalid Delivery Option',
                description: 'Testing validation',
                metadata: {
                    deliveryOption: 'Invalid Option' // This should fail validation
                }
            });

            await testRequest.validate();
            console.log('❌ Validation should have failed but passed');
        } catch (error) {
            console.log('✅ Request validation working:', error.message);
        }

    } catch (error) {
        console.error('❌ Error verifying delivery options:', error);
    } finally {
        await mongoose.disconnect();
        console.log('✅ Disconnected from MongoDB');
    }
};

// Run the verification
verifyDeliveryOptions();
