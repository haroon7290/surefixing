const mongoose = require('mongoose');

// Wallet ledger: one row per movement. `amount` is signed (+ in, − out) and
// `balanceAfter` is the user's wallet right after it. Rows with no user are
// the platform's own commission income.
const TYPES = [
  'deposit', // money sent to a company account, approved by an admin
  'withdrawal', // payout requested (taken from the wallet at once)
  'withdrawal_reversed', // payout rejected or cancelled: the money comes back
  'job_hold', // client → escrow when hiring
  'job_refund', // escrow → client (cancelled / technician withdrew)
  'job_earning', // escrow → technician on completion
  'rental_hold', // renter → escrow (rental cost + deposit)
  'rental_refund', // escrow → renter (deposit back, or everything if declined)
  'rental_earning', // escrow → supplier on return
  'installment_payment', // buyer → supplier, one month
  'installment_earning',
  'platform_fee'
];

const transactionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    type: { type: String, enum: TYPES, required: true },
    amount: { type: Number, required: true },
    balanceAfter: { type: Number, default: 0 },
    job: { type: mongoose.Schema.Types.ObjectId, ref: 'Job', default: null },
    rental: { type: mongoose.Schema.Types.ObjectId, ref: 'Rental', default: null },
    note: { type: String, default: '' }
  },
  { timestamps: true }
);

transactionSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('Transaction', transactionSchema);
module.exports.TYPES = TYPES;
