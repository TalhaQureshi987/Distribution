const mongoose = require("mongoose");

const ChatRoomSchema = new mongoose.Schema(
  {
    participant1Id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    participant1Name: { type: String, required: true },
    participant2Id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    participant2Name: { type: String, required: true },
    donationId: { type: mongoose.Schema.Types.ObjectId, ref: "Donation" },
    requestId: { type: mongoose.Schema.Types.ObjectId, ref: "Request" },
    lastMessage: { type: String },
    lastMessageAt: { type: Date },
    unreadCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model("ChatRoom", ChatRoomSchema);
