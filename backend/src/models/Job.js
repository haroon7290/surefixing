const mongoose = require('mongoose');

const STATUSES = ['pending', 'in_progress', 'completed', 'cancelled'];

const bidSchema = new mongoose.Schema(
  {
    technician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true },
    message: { type: String, default: '' },
    etaDays: { type: Number, default: 1 },
    status: { type: String, enum: ['pending', 'accepted', 'rejected'], default: 'pending' }
  },
  { timestamps: true }
);

const jobSchema = new mongoose.Schema(
  {
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: { type: String, required: true },
    description: { type: String, required: true },
    category: { type: String, default: 'general' },
    budget: { type: Number, default: 0 },
    location: { type: String, default: '' },
    images: { type: [String], default: [] },
    status: { type: String, enum: STATUSES, default: 'pending' },
    assignedTechnician: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    acceptedBid: { type: mongoose.Schema.Types.ObjectId, default: null },
    bids: [bidSchema],
    completedAt: { type: Date, default: null },
    rating: { type: Number, default: null },
    review: { type: String, default: '' }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Job', jobSchema);
module.exports.STATUSES = STATUSES;
