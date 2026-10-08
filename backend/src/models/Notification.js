const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, required: true },      // 'bid', 'message', 'job_status', 'kyc', etc.
    title: { type: String, required: true },
    body: { type: String, default: '' },
    data: { type: Object, default: {} },
    readAt: { type: Date, default: null }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Notification', notificationSchema);
