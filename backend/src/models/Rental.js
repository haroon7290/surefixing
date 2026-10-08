const mongoose = require('mongoose');

// Lifecycle:
//   requested ──approve──▶ active ──return──▶ returned        (type: rent)
//   requested ──approve──▶ active ──complete─▶ completed      (type: installment)
//   requested ──reject───▶ rejected
//   requested ──cancel───▶ cancelled (by renter)
// Stock is reserved on approve and released on return/complete.
const STATUSES = ['requested', 'active', 'returned', 'completed', 'rejected', 'cancelled'];

const rentalSchema = new mongoose.Schema(
  {
    tool: { type: mongoose.Schema.Types.ObjectId, ref: 'Tool', required: true, index: true },
    renter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    supplier: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    type: { type: String, enum: ['rent', 'installment'], required: true },
    startDate: { type: Date, default: Date.now },
    endDate: { type: Date },
    days: { type: Number, default: 0 },
    totalCost: { type: Number, default: 0 },
    deposit: { type: Number, default: 0 },
    monthsRemaining: { type: Number, default: 0 },
    fulfillment: { type: String, enum: ['pickup', 'delivery'], default: 'pickup' },
    note: { type: String, default: '' },
    status: { type: String, enum: STATUSES, default: 'requested' },
    rejectionReason: { type: String, default: '' },
    approvedAt: { type: Date, default: null },
    returnedAt: { type: Date, default: null },
    rating: { type: Number, default: null },
    review: { type: String, default: '' }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Rental', rentalSchema);
module.exports.STATUSES = STATUSES;
