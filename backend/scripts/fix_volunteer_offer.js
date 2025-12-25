const mongoose = require("mongoose");
const Donation = require("../models/Donation");
const VolunteerOffer = require("../models/VolunteerOffer");
const config = require("../config/environment");

// Connect to MongoDB using the same config as the server
mongoose.connect(config.mongoUri);

async function fixVolunteerOffer() {
  try {
    console.log("🔧 Fixing volunteer offer...\n");

    // Find the problematic volunteer offer
    const volunteerOffer = await VolunteerOffer.findById(
      "68ed60262285b66d8b70f070"
    );

    if (!volunteerOffer) {
      console.log("❌ Volunteer offer not found");
      return;
    }

    console.log(`📋 Found volunteer offer: ${volunteerOffer._id}`);
    console.log(`   Current ownerId: ${volunteerOffer.ownerId}`);
    console.log(`   ItemId: ${volunteerOffer.itemId}`);
    console.log(`   VolunteerId: ${volunteerOffer.volunteerId}`);

    // Find the donation to get the correct donor ID
    const donation = await Donation.findById(volunteerOffer.itemId);

    if (!donation) {
      console.log("❌ Donation not found");
      return;
    }

    console.log(`📦 Found donation: ${donation.title}`);
    console.log(`   DonorId: ${donation.donorId}`);
    console.log(`   DonorName: ${donation.donorName}`);

    // Fix the ownerId
    if (volunteerOffer.ownerId !== donation.donorId) {
      console.log(
        `\n🔧 Fixing ownerId from ${volunteerOffer.ownerId} to ${donation.donorId}`
      );

      volunteerOffer.ownerId = donation.donorId;
      await volunteerOffer.save();

      console.log(`✅ Volunteer offer fixed!`);
      console.log(`   New ownerId: ${volunteerOffer.ownerId}`);
    } else {
      console.log(`✅ OwnerId is already correct`);
    }

    // Now test if the offer appears in accepted offers
    console.log(`\n🔍 Testing accepted offers query...`);

    const acceptedOffers = await VolunteerOffer.find({
      ownerId: donation.donorId,
      status: { $in: ["approved", "completed"] },
    });

    console.log(
      `📋 Found ${acceptedOffers.length} accepted offers for donor ${donation.donorId}`
    );

    for (const offer of acceptedOffers) {
      console.log(
        `   - Offer ID: ${offer._id}, Status: ${offer.status}, VolunteerId: ${offer.volunteerId}`
      );
    }

    console.log("\n✅ Fix completed!");
  } catch (error) {
    console.error("❌ Error fixing volunteer offer:", error);
  } finally {
    mongoose.connection.close();
  }
}

// Run the fix
fixVolunteerOffer();
