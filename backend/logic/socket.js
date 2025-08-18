// socket.js
let ioInstance = null;

function initSocket(server) {
  const { Server } = require('socket.io');
  const io = new Server(server, {
    cors: {
      origin: '*', // restrict in production
      methods: ['GET', 'POST']
    }
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.headers['x-user-id'];
    // Accept token as user id for now. In production verify JWT.
    if (!token) {
      socket.user = { id: 'anonymous' };
    } else {
      socket.user = { id: token };
    }
    next();
  });

  io.on('connection', (socket) => {
    const userId = socket.user?.id || 'anonymous';
    console.log('Socket connected:', socket.id, 'user:', userId);

    socket.on('join_chat', (chatId) => {
      if (!chatId) return;
      socket.join(chatId);
      console.log(`${socket.id} joined ${chatId}`);
    });

    socket.on('leave_chat', (chatId) => {
      if (!chatId) return;
      socket.leave(chatId);
    });

    socket.on('send_message', async (data, ack) => {
      try {
        const { chatId, text = '', attachments = [] } = data || {};
        if (!chatId) {
          if (ack) ack({ ok: false, error: 'chatId required' });
          return;
        }
        const Message = require('./models/Message');
        const msg = await Message.create({
          chatId,
          senderId: socket.user.id,
          text,
          attachments
        });
        io.to(chatId).emit('new_message', msg);
        if (ack) ack({ ok: true, message: msg });
      } catch (err) {
        console.error('send_message error', err);
        if (ack) ack({ ok: false, error: 'server error' });
      }
    });

    socket.on('typing', (payload) => {
      const { chatId, isTyping } = payload || {};
      if (chatId) {
        socket.to(chatId).emit('typing', { userId: socket.user.id, isTyping });
      }
    });

    socket.on('disconnect', (reason) => {
      console.log('Socket disconnected', socket.id, 'reason:', reason);
    });
  });

  ioInstance = io;
  return io;
}

function getIO() {
  if (!ioInstance) throw new Error('Socket.IO not initialized. Call initSocket(server) first.');
  return ioInstance;
}

module.exports = { initSocket, getIO };
