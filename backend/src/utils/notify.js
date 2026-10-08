const Notification = require('../models/Notification');
const realtime = require('./realtime');

async function notify(userId, type, title, body = '', data = {}) {
  try {
    const doc = await Notification.create({ user: userId, type, title, body, data });
    // Push the same notification over the socket so connected clients get
    // a toast immediately, without polling.
    realtime.emit(userId, 'notification', {
      _id: doc._id,
      type,
      title,
      body,
      data,
      createdAt: doc.createdAt
    });
  } catch (err) {
    console.error('Notification failed:', err.message);
  }
}

module.exports = { notify };
