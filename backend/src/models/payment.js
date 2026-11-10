const mongoose = require('mongoose');
const { PAYMENT_METHODS } = require('../config/catalog');

// How a job or rental is paid. Embedded in Job and Rental.
//
//   wallet: none → held (money leaves the payer's wallet and waits in escrow)
//                → released (paid out, minus the platform fee) | refunded
//   cash:   none → cash_due → cash_paid (handed over in person; no fee)
const PAYMENT_STATUSES = ['none', 'held', 'released', 'refunded', 'cash_due', 'cash_paid'];

const paymentSchema = new mongoose.Schema(
  {
    method: { type: String, enum: PAYMENT_METHODS, default: 'cash' },
    status: { type: String, enum: PAYMENT_STATUSES, default: 'none' },
    amount: { type: Number, default: 0 }, // what the customer pays for the service / rental
    deposit: { type: Number, default: 0 }, // rentals: refundable part held with the amount
    fee: { type: Number, default: 0 }, // platform commission taken on release
    net: { type: Number, default: 0 }, // what the technician / supplier receives
    heldAt: { type: Date, default: null },
    settledAt: { type: Date, default: null }
  },
  { _id: false }
);

module.exports = { paymentSchema, PAYMENT_STATUSES };
