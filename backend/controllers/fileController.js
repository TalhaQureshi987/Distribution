// controllers/fileController.js
const { getBucket, ObjectId } = require("../config/db");
const Message = require("../models/Message");
const { getIO } = require("../logic/socket"); // may throw if socket not init (catch below)

async function uploadFileHandler(req, res) {
  try {
    if (!req.file) return res.status(400).json({ error: "No file" });
    const bucket = getBucket();
    const { originalname, mimetype, buffer } = req.file;
    const chatId = req.body.chatId || "unknown";
    const text = req.body.text || "";

    const uploadStream = bucket.openUploadStream(originalname, {
      contentType: mimetype,
      metadata: { uploadedBy: req.user.id, chatId },
    });

    uploadStream.end(buffer);

    uploadStream.on("finish", async (file) => {
      const fileId = file._id.toString();

      const msg = await Message.create({
        chatId,
        senderId: req.user.id,
        text,
        attachments: [
          {
            fileId,
            filename: originalname,
            contentType: mimetype,
            size: file.length,
          },
        ],
      });

      // emit via Socket.IO if available
      try {
        const io = getIO();
        io.to(chatId).emit("new_message", msg);
      } catch (err) {
        // socket may not be ready during tests — ignore
        console.warn("Socket.IO not ready to emit", err.message || err);
      }

      res.json({
        message: msg,
        fileUrl: `/files/${fileId}`,
      });
    });

    uploadStream.on("error", (err) => {
      console.error("Upload stream error", err);
      if (!res.headersSent) res.status(500).json({ error: "Upload failed" });
    });
  } catch (err) {
    console.error(err);
    if (!res.headersSent) res.status(500).json({ error: "Server error" });
  }
}

async function streamFileHandler(req, res) {
  try {
    const id = req.params.id;
    if (!ObjectId.isValid(id)) return res.status(400).send("Invalid id");

    const _id = new ObjectId(id);
    const bucket = getBucket();

    const filesColl =
      require("mongoose").connection.db.collection("uploads.files");
    const fileDoc = await filesColl.findOne({ _id });
    if (!fileDoc) return res.status(404).send("Not found");

    // (Optional) check authorization here: ensure req.user is member of chat before streaming
    res.set("Content-Type", fileDoc.contentType || "application/octet-stream");
    res.set("Content-Disposition", `inline; filename="${fileDoc.filename}"`);

    const downloadStream = bucket.openDownloadStream(_id);
    downloadStream.on("error", (err) => {
      console.error("Download stream error", err);
      if (!res.headersSent) res.status(500).end();
    });
    downloadStream.pipe(res);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) res.status(500).send("Server error");
  }
}

async function deleteFileHandler(req, res) {
  try {
    const id = req.params.id;
    if (!ObjectId.isValid(id)) return res.status(400).send("Invalid id");
    const _id = new ObjectId(id);
    const bucket = getBucket();

    bucket.delete(_id, async (err) => {
      if (err) {
        console.error("GridFS delete error", err);
        return res.status(500).send("Delete failed");
      }
      // remove references from messages
      await Message.updateMany(
        { "attachments.fileId": id },
        { $pull: { attachments: { fileId: id } } }
      );
      res.sendStatus(204);
    });
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
}

async function listMessagesHandler(req, res) {
  try {
    const { chatId } = req.params;
    const messages = await Message.find({ chatId })
      .sort({ createdAt: 1 })
      .lean();
    res.json(messages);
  } catch (err) {
    console.error(err);
    res.status(500).send("Server error");
  }
}

module.exports = {
  uploadFileHandler,
  streamFileHandler,
  deleteFileHandler,
  listMessagesHandler,
};
