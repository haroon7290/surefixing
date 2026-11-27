const mongoose = require('mongoose');
const { paymentSchema } = require('./payment');
const Counter = require('./Counter');

// Lifecycle:
//   requested ──approve──▶ active ──return──▶ returned                 (type: rent)
//   requested ──approve──▶ active ──handed over / received──▶ completed (type: purchase)
//   requested ──reject───▶ rejected
//   requested ──cancel───▶ cancelled (by renter)
// Stock is reserved on approve; released on return (rentals only: a sold
// tool doesn't come back). Older "installment" records were turned into
// purchases (see migrateInstallments).
const STATUSES = ['requested', 'active', 'returned', 'completed', 'rejected', 'cancelled'];

const rentalSchema = new mongoose.Schema(
  {
    tool: { type: mongoose.Schema.Types.ObjectId, ref: 'Tool', required: true, index: true },
    renter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    supplier: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, enum: ['rent', 'purchase'], required: true },
    // Invoice number, shown as INV-1001.
    number: { type: Number, unique: true, sparse: true },

    // Rentals.
    startDate: { type: Date, default: Date.now },
    endDate: { type: Date },
    days: { type: Number, default: 0 },
    dailyRate: { type: Number, default: 0 }, // snapshot, also the late fee per day
    deposit: { type: Number, default: 0 },
    lateDays: { type: Number, default: 0 },
    lateFee: { type: Number, default: 0 }, // taken from the deposit on a late return
    // Early return: only the days actually used are charged; the rent for the
    // rest comes back to the renter (from escrow, or simply not paid in cash).
    usedDays: { type: Number, default: 0 },
    earlyRefund: { type: Number, default: 0 },

    // Rent for all days, or the sale price. Delivery is charged on top.
    totalCost: { type: Number, default: 0 },
    deliveryFee: { type: Number, default: 0 },
    payment: { type: paymentSchema, default: () => ({}) },

    fulfillment: { type: String, enum: ['pickup', 'delivery'], default: 'pickup' },
    // Where to deliver (fulfillment = delivery). Pickups use the supplier's address.
    deliveryAddress: { type: String, default: '', trim: true, maxlength: 300 },
    note: { type: String, default: '' },
    status: { type: String, enum: STATUSES, default: 'requested' },
    rejectionReason: { type: String, default: '' },
    approvedAt: { type: Date, default: null },
    returnedAt: { type: Date, default: null },
    completedAt: { type: Date, default: null }, // purchases: handed over
    rating: { type: Number, default: null },
    review: { type: String, default: '' }
  },
  { timestamps: true }
);

// Every new rental or purchase gets the next invoice number.
rentalSchema.pre('save', async function numberInvoice(next) {
  if (this.number) return next();
  try {
    this.number = await Counter.next('invoice');
    next();
  } catch (err) {
    next(err);
  }
});

// Numbers records that don't have one yet (older data, bulk inserts),
// oldest first. Returns how many were numbered.
rentalSchema.statics.numberMissing = async function numberMissing() {
  const missing = await this.find({ $or: [{ number: null }, { number: { $exists: false } }] }).sort({ createdAt: 1 }).select('_id');
  for (const r of missing) await this.updateOne({ _id: r._id }, { $set: { number: await Counter.next('invoice') } });
  return missing.length;
};

// Tools used to be sold on monthly installments; now a sale is paid once.
// Older plans become purchases: finished plans are completed, open ones
// keep their state, and the price stays what was agreed.
rentalSchema.statics.migrateInstallments = async function migrateInstallments() {
  const res = await this.collection.updateMany(
    { type: 'installment' },
    { $set: { type: 'purchase' }, $unset: { monthsTotal: '', monthsPaid: '', monthlyAmount: '' } }
  );
  await mongoose.connection.collection('tools').updateMany(
    { $or: [{ installmentMonths: { $exists: true } }, { installmentMonthly: { $exists: true } }] },
    { $unset: { installmentMonths: '', installmentMonthly: '' } }
  );
  return res.modifiedCount || 0;
};

module.exports = mongoose.model('Rental', rentalSchema);
module.exports.STATUSES = STATUSES;
