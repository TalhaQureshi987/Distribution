const mongoose = require("mongoose");

const DeliveryCommissionSchema = new mongoose.Schema(
  {
    donationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Donation",
      required: true,
    },
    deliveryPersonId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    deliveryDistance: { type: Number, required: true, min: 0 }, // Distance in kilometers
    baseRate: { type: Number, required: true, min: 0, default: 50 }, // Base rate per km
    totalDeliveryPrice: { type: Number, required: true, min: 0 }, // Full calculated price
    commissionRate: { type: Number, required: true, min: 0, max: 100, default: 10 }, // Commission percentage
    commissionAmount: { type: Number, required: true, min: 0 }, // 10% commission for platform
    deliveryPayment: { type: Number, required: true, min: 0 }, // 90% payment for delivery person
    
    status: {
      type: String,
      enum: ["pending", "completed", "paid", "cancelled"],
      default: "pending"
    },
    
    // Payment tracking
    paymentProcessedAt: { type: Date },
    paymentMethod: {
      type: String,
      enum: ["bank_transfer", "mobile_money", "cash", "paypal", "stripe"],
    },
    paymentReference: { type: String },
    
    // Admin processing
    processedBy: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: "User" // Admin who processed the payment
    },
    processingNotes: { type: String },
  },
  { timestamps: true }
);

// Calculate pricing based on distance
DeliveryCommissionSchema.methods.calculatePricing = function() {
  this.totalDeliveryPrice = this.deliveryDistance * this.baseRate;
  this.commissionAmount = (this.totalDeliveryPrice * this.commissionRate) / 100;
  this.deliveryPayment = this.totalDeliveryPrice - this.commissionAmount;
};

// Pre-save hook to calculate pricing
DeliveryCommissionSchema.pre("save", function (next) {
  if (this.isModified('deliveryDistance') || this.isModified('baseRate') || this.isModified('commissionRate')) {
    this.calculatePricing();
  }
  next();
});

module.exports = mongoose.model("DeliveryCommission", DeliveryCommissionSchema);
