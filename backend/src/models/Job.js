const mongoose = require('mongoose');
const { URGENCY_LEVELS, JOB_STAGES } = require('../config/catalog');
const { paymentSchema } = require('./payment');
const { pointSchema } = require('../utils/geo');

// Lifecycle:
//   pending ──hire──▶ in_progress ──client confirms──▶ completed
//      │                  │  stage: hired → on_the_way → working → done
//      └──cancel──▶ cancelled ◀──cancel (before work starts) / admin
//   in_progress ──technician withdraws──▶ pending (reopened for quotes)
const STATUSES = ['pending', 'in_progress', 'completed', 'cancelled'];

const bidSchema = new mongoose.Schema(
  {
    technician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true, min: 0 },
    message: { type: String, default: '' },
    etaDays: { type: Number, default: 1, min: 0 },
    status: { type: String, enum: ['pending', 'accepted', 'rejected', 'withdrawn'], default: 'pending' }
  },
  { timestamps: true }
);

const historySchema = new mongoose.Schema(
  {
    event: { type: String, required: true }, // posted, bid, hired, on_the_way, working, done, completed, cancelled…
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
    // Where the work is, for technicians searching near them. Only the
    // distance and area name are ever sent to the app.
    geo: { type: pointSchema, default: undefined },
    area: { type: String, default: '', trim: true },
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

    // Progress while in_progress, reported by the technician.
    stage: { type: String, enum: JOB_STAGES, default: 'hired' },
    hiredAt: { type: Date, default: null },
    doneAt: { type: Date, default: null },
    completionNote: { type: String, default: '' },
    completionImages: { type: [String], default: [] },

    payment: { type: paymentSchema, default: () => ({}) },

    completedAt: { type: Date, default: null },
    cancelledAt: { type: Date, default: null },
    cancelReason: { type: String, default: '' },
    rating: { type: Number, default: null },
    review: { type: String, default: '' }
  },
  {
    timestamps: true,
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.geo;
        return ret;
      }
    }
  }
);

jobSchema.index({ status: 1, createdAt: -1 });
jobSchema.index({ geo: '2dsphere' });

jobSchema.methods.log = function (event, by, note = '') {
  this.history.push({ event, by: by || null, note, at: new Date() });
};

module.exports = mongoose.model('Job', jobSchema);
module.exports.STATUSES = STATUSES;
