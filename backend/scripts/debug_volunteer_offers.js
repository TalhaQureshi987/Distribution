const mongoose = require("mongoose");
const Donation = require("../models/Donation");
const VolunteerOffer = require("../models/VolunteerOffer");
const VolunteerAssignment = require("../models/VolunteerAssignment");
const Delivery = require("../models/Delivery");
const User = require("../models/User");
const config = require("../config/environment");

// Connect to MongoDB using the same config as the server
mongoose.connect(config.mongoUri);

async function debugVolunteerOffers() {
  try {
    console.log("🔍 Debugging volunteer offers and donations...\n");

    // Find all volunteer offers
    const allVolunteerOffers = await VolunteerOffer.find({})
      .populate("volunteerId", "name email")
      .populate("ownerId", "name email");

    console.log(`📊 Found ${allVolunteerOffers.length} total volunteer offers`);

    for (const offer of allVolunteerOffers) {
      console.log(`\n📋 Volunteer Offer ID: ${offer._id}`);
      console.log(`   Status: ${offer.status}`);
      console.log(`   Item Type: ${offer.itemType}`);
      console.log(
        `   Volunteer: ${offer.volunteerId?.name} (${offer.volunteerId?.email})`
      );
      console.log(`   Owner: ${offer.ownerId?.name} (${offer.ownerId?.email})`);
      console.log(`   Item ID: ${offer.itemId}`);
      console.log(`   Created: ${offer.createdAt}`);
      console.log(`   Approved: ${offer.approvedAt || "Not approved"}`);
      console.log(`   Completed: ${offer.completedAt || "Not completed"}`);

      if (offer.approverResponse) {
        console.log(
          `   Approver Response: ${
            offer.approverResponse.message || "No message"
          }`
        );
        console.log(`   Response Date: ${offer.approverResponse.respondedAt}`);
      }
    }

    // Find all donations
    const allDonations = await Donation.find({}).populate(
      "donorId",
      "name email"
    );

    console.log(`\n📦 Found ${allDonations.length} total donations`);

    for (const donation of allDonations) {
      console.log(`\n📦 Donation ID: ${donation._id}`);
      console.log(`   Title: ${donation.title}`);
      console.log(`   Status: ${donation.status}`);
      console.log(`   Verification Status: ${donation.verificationStatus}`);
      console.log(`   Delivery Option: ${donation.deliveryOption}`);
      console.log(
        `   Donor: ${donation.donorName} (${donation.donorId?.email})`
      );
      console.log(`   Created: ${donation.createdAt}`);
      console.log(`   Completed: ${donation.completedAt || "Not completed"}`);
    }

    // Find all volunteer assignments
    const allAssignments = await VolunteerAssignment.find({})
      .populate("volunteerId", "name email")
      .populate("donationId", "title");

    console.log(
      `\n🎯 Found ${allAssignments.length} total volunteer assignments`
    );

    for (const assignment of allAssignments) {
      console.log(`\n🎯 Assignment ID: ${assignment._id}`);
      console.log(`   Status: ${assignment.status}`);
      console.log(
        `   Volunteer: ${assignment.volunteerId?.name} (${assignment.volunteerId?.email})`
      );
      console.log(`   Donation: ${assignment.donationId?.title || "N/A"}`);
      console.log(`   Assigned: ${assignment.assignedAt}`);
      console.log(`   Started: ${assignment.startedAt || "Not started"}`);
      console.log(`   Completed: ${assignment.completedAt || "Not completed"}`);
    }

    // Find all deliveries
    const allDeliveries = await Delivery.find({})
      .populate("deliveryPerson", "name email")
      .populate("itemId", "title");

    console.log(`\n🚚 Found ${allDeliveries.length} total deliveries`);

    for (const delivery of allDeliveries) {
      console.log(`\n🚚 Delivery ID: ${delivery._id}`);
      console.log(`   Status: ${delivery.status}`);
      console.log(`   Type: ${delivery.deliveryType}`);
      console.log(
        `   Delivery Person: ${delivery.deliveryPerson?.name} (${delivery.deliveryPerson?.email})`
      );
      console.log(`   Item: ${delivery.itemId?.title || "N/A"}`);
      console.log(`   Created: ${delivery.createdAt}`);
      console.log(`   Completed: ${delivery.completedAt || "Not completed"}`);
    }

    // Check for specific user mentioned in the logs
    const userEmail = "talhaqureshi00123@gmail.com";
    const user = await User.findOne({ email: userEmail });

    if (user) {
      console.log(`\n👤 Found user: ${user.name} (${user.email})`);
      console.log(`   ID: ${user._id}`);
      console.log(`   Role: ${user.role}`);

      // Check volunteer offers for this user as owner
      const userVolunteerOffers = await VolunteerOffer.find({
        ownerId: user._id,
      })
        .populate("volunteerId", "name email")
        .populate("itemId", "title");

      console.log(
        `   📋 Volunteer offers as owner: ${userVolunteerOffers.length}`
      );
      for (const offer of userVolunteerOffers) {
        console.log(
          `      - Offer ID: ${offer._id}, Status: ${offer.status}, Volunteer: ${offer.volunteerId?.name}`
        );
      }

      // Check volunteer offers for this user as volunteer
      const userAsVolunteerOffers = await VolunteerOffer.find({
        volunteerId: user._id,
      })
        .populate("ownerId", "name email")
        .populate("itemId", "title");

      console.log(
        `   🎯 Volunteer offers as volunteer: ${userAsVolunteerOffers.length}`
      );
      for (const offer of userAsVolunteerOffers) {
        console.log(
          `      - Offer ID: ${offer._id}, Status: ${offer.status}, Owner: ${offer.ownerId?.name}`
        );
      }

      // Check donations by this user
      const userDonations = await Donation.find({
        donorId: user._id,
      });

      console.log(`   📦 Donations: ${userDonations.length}`);
      for (const donation of userDonations) {
        console.log(
          `      - Donation ID: ${donation._id}, Title: ${donation.title}, Status: ${donation.status}`
        );
      }
    }

    console.log("\n✅ Debug completed!");
  } catch (error) {
    console.error("❌ Error debugging volunteer offers:", error);
  } finally {
    mongoose.connection.close();
  }
}

// Run the debug
debugVolunteerOffers();
