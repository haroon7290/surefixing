// Real-time push via Socket.IO. Each authenticated socket joins a room
// named after its userId, so emitting to that room delivers to all of
// that user's connected devices/tabs without us tracking socket ids.
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');

let io = null;

function init(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'] }
  });

  io.use((socket, next) => {
    // Token comes via auth handshake (preferred) or query param fallback.
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Missing token'));
    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = String(payload.id);
      socket.role = payload.role;
      next();
    } catch (_err) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);
    if (socket.role) socket.join(`role:${socket.role}`);
  });
}

function emit(userId, event, payload) {
  if (!io || !userId) return;
  io.to(`user:${String(userId)}`).emit(event, payload);
}

function emitRole(role, event, payload) {
  if (!io || !role) return;
  io.to(`role:${role}`).emit(event, payload);
}

module.exports = { init, emit, emitRole };
