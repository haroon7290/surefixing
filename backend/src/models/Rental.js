const mongoose = require('mongoose');
const { paymentSchema } = require('./payment');

// Lifecycle:
//   requested ──approve──▶ active ──return──▶ returned        (type: rent)
//   requested ──approve──▶ active ──all months paid──▶ completed (type: installment)
//   requested ──reject───▶ rejected
//   requested ──cancel───▶ cancelled (by renter)
// Stock is reserved on approve and released on return.
const STATUSES = ['requested', 'active', 'returned', 'completed', 'rejected', 'cancelled'];

const rentalSchema = new mongoose.Schema(
  {
    tool: { type: mongoose.Schema.Types.ObjectId, ref: 'Tool', required: true, index: true },
    renter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    supplier: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, enum: ['rent', 'installment'], required: true },

    // Rentals.
    startDate: { type: Date, default: Date.now },
    endDate: { type: Date },
    days: { type: Number, default: 0 },
    dailyRate: { type: Number, default: 0 }, // snapshot, also the late fee per day
    deposit: { type: Number, default: 0 },
    lateDays: { type: Number, default: 0 },
    lateFee: { type: Number, default: 0 }, // taken from the deposit on a late return

    // Installment purchases.
    monthsTotal: { type: Number, default: 0 },
    monthsPaid: { type: Number, default: 0 },
    monthlyAmount: { type: Number, default: 0 },

    totalCost: { type: Number, default: 0 },
    payment: { type: paymentSchema, default: () => ({}) },

    fulfillment: { type: String, enum: ['pickup', 'delivery'], default: 'pickup' },
    // Where to deliver (fulfillment = delivery). Pickups use the supplier's address.
    deliveryAddress: { type: String, default: '', trim: true, maxlength: 300 },
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
