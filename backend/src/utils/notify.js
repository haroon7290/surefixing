const Notification = require('../models/Notification');
const realtime = require('./realtime');

// Persists an in-app notification and pushes it over the socket so
// connected clients get a toast immediately. `data` carries deep-link ids
// (jobId, toolId, rentalId, ...) the app uses to open the right screen.
async function notify(userId, type, title, body = '', data = {}) {
  if (!userId) return;
  try {
    const doc = await Notification.create({ user: userId, type, title, body, data });
    realtime.emit(userId, 'notification', {
      _id: doc._id,
      type,
      title,
      body,
      data,
      readAt: null,
      createdAt: doc.createdAt
    });
  } catch (err) {
    console.error('Notification failed:', err.message);
  }
}

module.exports = { notify };
