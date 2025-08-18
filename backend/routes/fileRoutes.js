// // routes/fileRoutes.js
// const express = require('express');
// const multer = require('multer');
// const router = express.Router();

// const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } }); // 10MB

// const auth = require('../middleware/authMiddleware');
// const {
//   uploadFileHandler,
//   streamFileHandler,
//   deleteFileHandler,
//   listMessagesHandler
// } = require('../controllers/fileController');

// router.post('/upload', auth, upload.single('file'), uploadFileHandler);
// router.get('/files/:id', auth, streamFileHandler);         // auth optional but recommended
// router.delete('/files/:id', auth, deleteFileHandler);
// router.get('/chats/:chatId/messages', auth, listMessagesHandler);

// module.exports = router;
