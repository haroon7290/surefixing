const mongoose = require('mongoose');

// A company account customers send money to (bank or mobile wallet). Admins
// manage the list; only active ones are shown in the app.
const paymentAccountSchema = new mongoose.Schema(
  {
    kind: { type: String, enum: ['bank', 'mobile_wallet'], default: 'bank' },
    provider: { type: String, required: true, trim: true, maxlength: 60 }, // e.g. "Meezan Bank", "JazzCash"
    accountTitle: { type: String, required: true, trim: true, maxlength: 80 },
    accountNumber: { type: String, required: true, trim: true, maxlength: 40 },
    iban: { type: String, default: '', trim: true, maxlength: 40 },
    instructions: { type: String, default: '', trim: true, maxlength: 300 },
    active: { type: Boolean, default: true },
    order: { type: Number, default: 0 }
  },
  { timestamps: true }
);

module.exports = mongoose.model('PaymentAccount', paymentAccountSchema);
