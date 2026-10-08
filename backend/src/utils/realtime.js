// Real-time push via Socket.IO. Each authenticated socket joins a room
// named after its userId, so emitting to that room delivers to all of
// that user's connected devices/tabs without us tracking socket ids.
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const config = require('../config');

let io = null;
// userId -> number of open sockets; drives the "online" dot in the app.
const online = new Map();

function touchLastSeen(userId) {
  // Lazy require avoids a circular import (models -> realtime -> models).
  const User = require('../models/User');
  User.updateOne({ _id: userId }, { $set: { lastSeenAt: new Date() } }).catch(() => {});
}

function init(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: config.corsOrigins.includes('*') ? '*' : config.corsOrigins, methods: ['GET', 'POST'] }
  });

  io.use((socket, next) => {
    // Token comes via auth handshake (preferred) or query param fallback.
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Missing token'));
    try {
      const payload = jwt.verify(token, config.jwtSecret);
      socket.userId = String(payload.id);
      socket.role = payload.role;
      next();
    } catch (_err) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const uid = socket.userId;
    socket.join(`user:${uid}`);
    if (socket.role) socket.join(`role:${socket.role}`);
    online.set(uid, (online.get(uid) || 0) + 1);
    touchLastSeen(uid);

    // Chat typing indicator: relayed to the other participant only.
    socket.on('typing', (data = {}) => {
      const to = String(data.to || '');
      if (!mongoose.isValidObjectId(to) || to === uid) return;
      io.to(`user:${to}`).emit('typing', {
        jobId: String(data.jobId || ''),
        from: uid,
        typing: data.typing !== false
      });
    });

    socket.on('disconnect', () => {
      const n = (online.get(uid) || 1) - 1;
      if (n <= 0) online.delete(uid);
      else online.set(uid, n);
      touchLastSeen(uid);
    });
  });
}

function emit(userId, event, payload) {
  if (!io || !userId) return;
  io.to(`user:${String(userId._id || userId)}`).emit(event, payload);
}

function emitRole(role, event, payload) {
  if (!io || !role) return;
  io.to(`role:${role}`).emit(event, payload);
}

function isOnline(userId) {
  return online.has(String(userId));
}

// Used when an admin suspends an account: drop its live sockets.
function disconnectUser(userId) {
  if (!io) return;
  io.in(`user:${String(userId)}`).disconnectSockets(true);
}

function close() {
  if (io) io.close();
  io = null;
  online.clear();
}

module.exports = { init, emit, emitRole, isOnline, disconnectUser, close };
