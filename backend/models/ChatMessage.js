const mongoose = require("mongoose");


const ChatMessageSchema = new mongoose.Schema(
{
roomId: { type: mongoose.Schema.Types.ObjectId, ref: "ChatRoom", required: true },
senderId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
senderName: { type: String, required: true },
receiverId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
receiverName: { type: String, required: true },
message: { type: String, default: "" },
messageType: { type: String, enum: ["text", "image", "location"], default: "text" },
imageUrl: { type: String },
latitude: { type: Number },
longitude: { type: Number },
isRead: { type: Boolean, default: false },
isDelivered: { type: Boolean, default: false },
deliveredAt: { type: Date },
readAt: { type: Date },
replyTo: { type: mongoose.Schema.Types.ObjectId, ref: "ChatMessage" },
},
{ timestamps: { createdAt: "timestamp", updatedAt: "updatedAt" } }
);


ChatMessageSchema.index({ roomId: 1, timestamp: -1 });
ChatMessageSchema.index({ receiverId: 1, isRead: 1 });


module.exports = mongoose.model("ChatMessage", ChatMessageSchema);