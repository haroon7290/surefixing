const mongoose = require('mongoose');
const { URGENCY_LEVELS } = require('../config/catalog');

const STATUSES = ['pending', 'in_progress', 'completed', 'cancelled'];

const bidSchema = new mongoose.Schema(
  {
    technician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true, min: 0 },
    message: { type: String, default: '' },
    etaDays: { type: Number, default: 1, min: 0 },
    status: { type: String, enum: ['pending', 'accepted', 'rejected'], default: 'pending' }
  },
  { timestamps: true }
);

const historySchema = new mongoose.Schema(
  {
    status: { type: String, required: true }, // a job status or an event like 'bid_accepted'
    note: { type: String, default: '' },
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    at: { type: Date, default: Date.now }
  },
  { _id: false }
);

const jobSchema = new mongoose.Schema(
  {
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, required: true, trim: true },
    description: { type: String, required: true },
    category: { type: String, default: 'general' },
    budget: { type: Number, default: 0, min: 0 },
    location: { type: String, default: '' },
    city: { type: String, default: '', trim: true },
    urgency: { type: String, enum: URGENCY_LEVELS, default: 'normal' },
    preferredDate: { type: Date, default: null },
    images: { type: [String], default: [] },
    status: { type: String, enum: STATUSES, default: 'pending' },

    // Direct service request: the client asked one technician specifically.
    // Hidden from the open marketplace until the client opens it to everyone.
    requestedTechnician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    requestDeclined: { type: Boolean, default: false },

    assignedTechnician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    acceptedBid: { type: mongoose.Schema.Types.ObjectId, default: null },
    agreedPrice: { type: Number, default: null },
    bids: [bidSchema],
    history: { type: [historySchema], default: [] },

    completedAt: { type: Date, default: null },
    cancelledAt: { type: Date, default: null },
    cancelReason: { type: String, default: '' },
    rating: { type: Number, default: null },
    review: { type: String, default: '' }
  },
  { timestamps: true }
);

jobSchema.index({ status: 1, createdAt: -1 });

jobSchema.methods.log = function (status, by, note = '') {
  this.history.push({ status, by: by || null, note, at: new Date() });
};

jobSchema.methods.isParticipant = function (userId) {
  const id = String(userId);
  return [this.client, this.assignedTechnician, this.requestedTechnician]
    .filter(Boolean)
    .some((p) => String(p._id || p) === id);
};

module.exports = mongoose.model('Job', jobSchema);
module.exports.STATUSES = STATUSES;
