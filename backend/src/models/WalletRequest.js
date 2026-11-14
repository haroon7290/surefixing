const mongoose = require('mongoose');

// Money in and out of the wallet through the company's own accounts,
// checked by an admin:
//   deposit:    the user sends money to a company account, then submits the
//               amount and the transaction ID → admin approves → wallet credited
//   withdrawal: the user asks for money to be sent to their account → the
//               amount leaves the wallet at once (so it can't be spent twice)
//               → admin sends it and approves, or rejects and it comes back
// Lifecycle: pending → approved | rejected | cancelled (by the user, while pending)
const KINDS = ['deposit', 'withdrawal'];
const STATUSES = ['pending', 'approved', 'rejected', 'cancelled'];
const PAYOUT_METHODS = ['bank', 'mobile_wallet'];

const accountSnapshot = new mongoose.Schema(
  {
    method: { type: String, enum: PAYOUT_METHODS, default: 'bank' },
    provider: { type: String, default: '', trim: true },
    accountTitle: { type: String, default: '', trim: true },
    accountNumber: { type: String, default: '', trim: true }
  },
  { _id: false }
);

const walletRequestSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    kind: { type: String, enum: KINDS, required: true },
    amount: { type: Number, required: true, min: 1 },
    status: { type: String, enum: STATUSES, default: 'pending', index: true },

    // Deposits: where the money was sent and the proof.
    companyAccount: { type: mongoose.Schema.Types.ObjectId, ref: 'PaymentAccount', default: null },
    sentTo: { type: accountSnapshot, default: undefined }, // copy of the company account at the time
    transactionId: { type: String, default: '', trim: true },
    transactionKey: { type: String, default: '' }, // normalised, for duplicate checks
    proofImage: { type: String, default: '' },

    // Withdrawals: where to send the money.
    payout: { type: accountSnapshot, default: undefined },

    note: { type: String, default: '', trim: true }, // from the user
    adminNote: { type: String, default: '', trim: true }, // reason for a rejection, or a remark
    reference: { type: String, default: '', trim: true }, // admin's transfer reference for a payout
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    reviewedAt: { type: Date, default: null }
  },
  { timestamps: true }
);

walletRequestSchema.index({ kind: 1, status: 1, createdAt: -1 });
walletRequestSchema.index({ transactionKey: 1 });

walletRequestSchema.statics.normalizeTx = (id) => String(id || '').replace(/[\s-]/g, '').toUpperCase();

module.exports = mongoose.model('WalletRequest', walletRequestSchema);
module.exports.KINDS = KINDS;
module.exports.STATUSES = STATUSES;
module.exports.PAYOUT_METHODS = PAYOUT_METHODS;
