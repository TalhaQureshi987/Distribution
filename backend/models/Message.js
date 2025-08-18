const mongoose =require ('mongoose')

const messageSchema = new mongoose.Schema({
  chatId: String,
  senderId: String,
  text: { type: String, default: '' },
  attachments: [{
    fileId: String,     // GridFS file id (as hex string)
    filename: String,
    contentType: String,
    size: Number,
    thumbFileId: String // optional small thumbnail file id
  }],
  createdAt: { type: Date, default: Date.now }
});
messageSchema.index({ chatId: 1, createdAt: -1 });
const Message = mongoose.model('Message', messageSchema)