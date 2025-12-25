const mongoose = require("mongoose");
const Donation = require("../models/Donation");
const VolunteerOffer = require("../models/VolunteerOffer");
const VolunteerAssignment = require("../models/VolunteerAssignment");
const Delivery = require("../models/Delivery");
const config = require("../config/environment");

// Connect to MongoDB using the same config as the server
mongoose.connect(config.mongoUri);

async function checkCompletedVolunteerDonations() {
  try {
    console.log("🔍 Checking for completed volunteer donations...\n");

    // Find all completed donations
    const completedDonations = await Donation.find({ status: "completed" });
    console.log(`📊 Found ${completedDonations.length} completed donations`);

    for (const donation of completedDonations) {
      console.log(`\n📦 Donation: ${donation.title} (ID: ${donation._id})`);
      console.log(`   Status: ${donation.status}`);
      console.log(`   Completed At: ${donation.completedAt}`);
      console.log(`   Delivery Option: ${donation.deliveryOption}`);

      // Check if this donation has volunteer offers
      const volunteerOffers = await VolunteerOffer.find({
        itemId: donation._id,
        itemType: "donation",
      });

      console.log(`   📋 Volunteer Offers: ${volunteerOffers.length}`);

      for (const offer of volunteerOffers) {
        console.log(
          `      - Offer ID: ${offer._id}, Status: ${offer.status}, Volunteer: ${offer.volunteerId}`
        );

        // If donation is completed but volunteer offer is still approved, update it
        if (offer.status === "approved") {
          console.log(
            `      🔄 Updating volunteer offer status to completed...`
          );
          offer.status = "completed";
          offer.completedAt = donation.completedAt || new Date();
          await offer.save();
          console.log(
            `      ✅ Updated volunteer offer ${offer._id} to completed`
          );
        }
      }

      // Check for volunteer assignments
      const volunteerAssignments = await VolunteerAssignment.find({
        donationId: donation._id,
      });

      console.log(
        `   🎯 Volunteer Assignments: ${volunteerAssignments.length}`
      );

      for (const assignment of volunteerAssignments) {
        console.log(
          `      - Assignment ID: ${assignment._id}, Status: ${assignment.status}, Volunteer: ${assignment.volunteerId}`
        );

        // If donation is completed but assignment is not completed, update it
        if (assignment.status !== "completed") {
          console.log(
            `      🔄 Updating volunteer assignment status to completed...`
          );
          assignment.status = "completed";
          assignment.completedAt = donation.completedAt || new Date();
          await assignment.save();
          console.log(
            `      ✅ Updated volunteer assignment ${assignment._id} to completed`
          );
        }
      }

      // Check for deliveries
      const deliveries = await Delivery.find({
        itemId: donation._id,
        itemType: "Donation",
      });

      console.log(`   🚚 Deliveries: ${deliveries.length}`);

      for (const delivery of deliveries) {
        console.log(
          `      - Delivery ID: ${delivery._id}, Status: ${delivery.status}, Type: ${delivery.deliveryType}`
        );
      }
    }

    // Also check for any volunteer offers that should be completed
    const approvedVolunteerOffers = await VolunteerOffer.find({
      status: "approved",
      itemType: "donation",
    }).populate("itemId");

    console.log(
      `\n🔍 Found ${approvedVolunteerOffers.length} approved volunteer offers for donations`
    );

    for (const offer of approvedVolunteerOffers) {
      if (offer.itemId && offer.itemId.status === "completed") {
        console.log(
          `\n🔄 Found approved volunteer offer for completed donation:`
        );
        console.log(`   Offer ID: ${offer._id}`);
        console.log(
          `   Donation: ${offer.itemId.title} (Status: ${offer.itemId.status})`
        );
        console.log(`   Volunteer: ${offer.volunteerId}`);

        // Update the volunteer offer to completed
        offer.status = "completed";
        offer.completedAt = offer.itemId.completedAt || new Date();
        await offer.save();
        console.log(`   ✅ Updated volunteer offer to completed`);
      }
    }

    console.log("\n✅ Check completed!");
  } catch (error) {
    console.error("❌ Error checking completed volunteer donations:", error);
  } finally {
    mongoose.connection.close();
  }
}

// Run the check
checkCompletedVolunteerDonations();
