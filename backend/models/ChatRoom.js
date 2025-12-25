// models/ChatRoom.js
const mongoose = require("mongoose");


const ChatRoomSchema = new mongoose.Schema(
{
participant1Id: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
participant1Name: { type: String, required: true },
participant2Id: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
participant2Name: { type: String, required: true },
donationId: { type: mongoose.Schema.Types.ObjectId, ref: "Donation" },
requestId: { type: mongoose.Schema.Types.ObjectId, ref: "Request" },
lastMessage: { type: String },
lastMessageAt: { type: Date },
unreadCount: { type: Number, default: 0 },
},
{ timestamps: true }
);


// Ensure canonical ordering to prevent duplicates regardless of creation order
ChatRoomSchema.pre("validate", function (next) {
if (!this.participant1Id || !this.participant2Id) return next();
const a = this.participant1Id.toString();
const b = this.participant2Id.toString();
if (a > b) {
// swap ids
const tmpId = this.participant1Id; this.participant1Id = this.participant2Id; this.participant2Id = tmpId;
// swap names to stay aligned
const tmpName = this.participant1Name; this.participant1Name = this.participant2Name; this.participant2Name = tmpName;
}
next();
});


// Unique pair constraint after canonicalization
ChatRoomSchema.index({ participant1Id: 1, participant2Id: 1 }, { unique: true });


module.exports = mongoose.model("ChatRoom", ChatRoomSchema);