const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema(
  {
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    senderRole: { type: String, enum: ['user', 'admin'], required: true },
    body: { type: String, required: true },
    attachments: [{
      url: String,
      name: String,
      type: String,
      size: Number,
    }],
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const SupportTicketSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: { type: String, required: true },
    category: { type: String, enum: ['General', 'Payment', 'Account', 'Bug', 'Feature'], default: 'General', index: true },
    priority: { type: String, enum: ['Low', 'Medium', 'High', 'Critical'], default: 'Medium', index: true },
    status: { type: String, enum: ['open', 'pending', 'closed'], default: 'open', index: true },
    messages: [MessageSchema],
    attachments: [{
      url: String,
      name: String,
      type: String,
      size: Number,
    }],
  },
  { timestamps: true }
);

SupportTicketSchema.index({ status: 1, updatedAt: -1 });

module.exports = mongoose.model('SupportTicket', SupportTicketSchema);
