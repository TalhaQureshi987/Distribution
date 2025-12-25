const mongoose = require("mongoose");
const Donation = require("../models/Donation");
const VolunteerOffer = require("../models/VolunteerOffer");
const User = require("../models/User");
const config = require("../config/environment");

// Connect to MongoDB using the same config as the server
mongoose.connect(config.mongoUri);

async function testVolunteerOffer() {
  try {
    console.log("🧪 Testing volunteer offer creation...\n");

    // Find a donation with Volunteer Delivery option
    const volunteerDonation = await Donation.findOne({
      deliveryOption: "Volunteer Delivery",
      status: "available",
      verificationStatus: "verified",
    });

    if (!volunteerDonation) {
      console.log("❌ No volunteer delivery donations found");
      return;
    }

    console.log(
      `📦 Found donation: ${volunteerDonation.title} (ID: ${volunteerDonation._id})`
    );
    console.log(
      `   Donor: ${volunteerDonation.donorName} (ID: ${volunteerDonation.donorId})`
    );
    console.log(`   Status: ${volunteerDonation.status}`);
    console.log(`   Verification: ${volunteerDonation.verificationStatus}`);

    // Find a user to act as volunteer (not the donor)
    const volunteer = await User.findOne({
      _id: { $ne: volunteerDonation.donorId },
      role: { $in: ["volunteer", "donor"] }, // Donors can also volunteer
    });

    if (!volunteer) {
      console.log("❌ No suitable volunteer found");
      return;
    }

    console.log(
      `\n👤 Found volunteer: ${volunteer.name} (ID: ${volunteer._id})`
    );
    console.log(`   Email: ${volunteer.email}`);
    console.log(`   Role: ${volunteer.role}`);

    // Check if volunteer already has an offer for this donation
    const existingOffer = await VolunteerOffer.findOne({
      itemId: volunteerDonation._id,
      itemType: "donation",
      volunteerId: volunteer._id,
      status: { $in: ["pending", "approved"] },
    });

    if (existingOffer) {
      console.log(`\n⚠️ Volunteer already has an offer for this donation:`);
      console.log(`   Offer ID: ${existingOffer._id}`);
      console.log(`   Status: ${existingOffer.status}`);
      return;
    }

    // Create volunteer offer
    console.log(`\n🤝 Creating volunteer offer...`);

    const volunteerOffer = new VolunteerOffer({
      itemId: volunteerDonation._id,
      itemType: "donation",
      ownerId: volunteerDonation.donorId,
      volunteerId: volunteer._id,
      message: "I would like to help deliver this donation to those in need.",
      status: "pending",
      offeredAt: new Date(),
    });

    await volunteerOffer.save();

    console.log(`✅ Volunteer offer created successfully!`);
    console.log(`   Offer ID: ${volunteerOffer._id}`);
    console.log(`   Status: ${volunteerOffer.status}`);
    console.log(`   Created: ${volunteerOffer.createdAt}`);

    // Now test the approval process
    console.log(`\n🔍 Testing approval process...`);

    // Simulate donor approval
    volunteerOffer.status = "approved";
    volunteerOffer.approvedAt = new Date();
    volunteerOffer.approverResponse = {
      message: "Thank you for volunteering! Please proceed with the delivery.",
      respondedAt: new Date(),
    };

    await volunteerOffer.save();

    console.log(`✅ Volunteer offer approved!`);
    console.log(`   Status: ${volunteerOffer.status}`);
    console.log(`   Approved: ${volunteerOffer.approvedAt}`);

    // Check if the offer now appears in the accepted offers query
    console.log(`\n🔍 Checking if offer appears in accepted offers...`);

    const acceptedOffers = await VolunteerOffer.find({
      ownerId: volunteerDonation.donorId,
      status: { $in: ["approved", "completed"] },
    }).populate("volunteerId", "name email");

    console.log(`📋 Found ${acceptedOffers.length} accepted offers for donor`);

    for (const offer of acceptedOffers) {
      console.log(
        `   - Offer ID: ${offer._id}, Status: ${offer.status}, Volunteer: ${offer.volunteerId?.name}`
      );
    }

    console.log("\n✅ Test completed successfully!");
  } catch (error) {
    console.error("❌ Error testing volunteer offer:", error);
  } finally {
    mongoose.connection.close();
  }
}

// Run the test
testVolunteerOffer();
