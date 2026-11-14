// Sandbox wallet and escrow. Balances are demo credit — no real money moves —
// but the bookkeeping is real: every change is one atomic balance update plus
// a Transaction row, and money held for a job or rental is tracked on that
// document's `payment` until it is released or refunded.
const User = require('../models/User');
const Transaction = require('../models/Transaction');
const config = require('../config');
const realtime = require('../utils/realtime');
const { HttpError } = require('../utils/http');

const round = (n) => Math.round(Number(n) || 0);

function feeFor(amount) {
  return round((amount * config.platformFeePercent) / 100);
}

function insufficient(needed, balance) {
  const err = new HttpError(402, 'Your wallet balance is too low. Add funds or choose cash.');
  err.code = 'insufficient_funds';
  err.details = { needed, balance };
  return err;
}

async function record(userId, type, amount, balanceAfter, ref = {}) {
  const tx = await Transaction.create({
    user: userId || null,
    type,
    amount,
    balanceAfter,
    job: ref.job || null,
    rental: ref.rental || null,
    note: ref.note || ''
  });
  if (userId) realtime.emit(userId, 'wallet:update', { balance: balanceAfter, type, amount });
  return tx;
}

// Adds money to a wallet.
async function credit(userId, amount, type, ref) {
  const value = round(amount);
  if (value <= 0) return null;
  const user = await User.findByIdAndUpdate(userId, { $inc: { walletBalance: value } }, { new: true });
  if (!user) return null;
  return record(userId, type, value, user.walletBalance, ref);
}

// Takes money from a wallet, never below zero: the balance check and the
// update are one database operation, so two debits can't both succeed.
async function debit(userId, amount, type, ref) {
  const value = round(amount);
  if (value <= 0) return null;
  const user = await User.findOneAndUpdate(
    { _id: userId, walletBalance: { $gte: value } },
    { $inc: { walletBalance: -value } },
    { new: true }
  );
  if (!user) {
    const current = await User.findById(userId).select('walletBalance');
    throw insufficient(value, current ? current.walletBalance : 0);
  }
  return record(userId, type, -value, user.walletBalance, ref);
}

async function platformFee(amount, ref) {
  const value = round(amount);
  if (value <= 0) return null;
  return record(null, 'platform_fee', value, 0, ref);
}

// ------------------------------------------------------------------ jobs

// Hiring: wallet jobs move the agreed price into escrow now.
async function holdForJob(job, method) {
  const amount = round(job.agreedPrice);
  job.payment = { method, status: 'cash_due', amount, deposit: 0, fee: 0, net: amount, heldAt: null, settledAt: null };
  if (method !== 'wallet') return;
  await debit(job.client, amount, 'job_hold', { job: job._id, note: job.title });
  const fee = feeFor(amount);
  Object.assign(job.payment, { status: 'held', fee, net: amount - fee, heldAt: new Date() });
}

// Completion: escrow goes to the technician minus the platform fee.
async function releaseJob(job) {
  const p = job.payment;
  if (!p || p.status === 'released' || p.status === 'cash_paid') return;
  if (p.status === 'held') {
    await credit(job.assignedTechnician, p.net, 'job_earning', { job: job._id, note: job.title });
    await platformFee(p.fee, { job: job._id, note: job.title });
    p.status = 'released';
  } else if (p.status === 'cash_due') {
    p.status = 'cash_paid';
  }
  p.settledAt = new Date();
}

// Cancellation / technician withdrawal: escrow goes back to the client.
async function refundJob(job) {
  const p = job.payment;
  if (!p) return;
  if (p.status === 'held') {
    await credit(job.client, p.amount, 'job_refund', { job: job._id, note: job.title });
    p.status = 'refunded';
    p.settledAt = new Date();
  } else if (p.status === 'cash_due') {
    p.status = 'none';
  }
}

// --------------------------------------------------------------- rentals

// Requesting a rental with the wallet holds the rental cost and the deposit.
async function holdForRental(rental, method, note) {
  const amount = round(rental.totalCost);
  const deposit = round(rental.deposit);
  rental.payment = { method, status: 'cash_due', amount, deposit, fee: 0, net: amount, heldAt: null, settledAt: null };
  if (method !== 'wallet') return;
  await debit(rental.renter, amount + deposit, 'rental_hold', { rental: rental._id, note });
  const fee = feeFor(amount);
  Object.assign(rental.payment, { status: 'held', fee, net: amount - fee, heldAt: new Date() });
}

// Declined / cancelled before it started: everything goes back.
async function refundRental(rental, note) {
  const p = rental.payment;
  if (!p) return;
  if (p.status === 'held') {
    await credit(rental.renter, p.amount + p.deposit, 'rental_refund', { rental: rental._id, note });
    p.status = 'refunded';
    p.settledAt = new Date();
  } else if (p.status === 'cash_due') {
    p.status = 'none';
  }
}

// Returned: the supplier is paid (rental minus fee, plus any late fee) and
// the renter gets the deposit back minus that late fee.
async function settleRental(rental, note) {
  const p = rental.payment;
  if (!p || p.status === 'released' || p.status === 'cash_paid') return;
  if (p.status === 'held') {
    const late = Math.min(round(rental.lateFee), p.deposit);
    await credit(rental.supplier, p.net + late, 'rental_earning', { rental: rental._id, note });
    await platformFee(p.fee, { rental: rental._id, note });
    await credit(rental.renter, p.deposit - late, 'rental_refund', { rental: rental._id, note: `Deposit returned — ${note}` });
    p.status = 'released';
  } else if (p.status === 'cash_due') {
    p.status = 'cash_paid';
  }
  p.settledAt = new Date();
}

// One monthly installment from the buyer's wallet to the supplier.
async function payInstallment(rental, note) {
  const amount = round(rental.monthlyAmount);
  await debit(rental.renter, amount, 'installment_payment', { rental: rental._id, note });
  const fee = feeFor(amount);
  await credit(rental.supplier, amount - fee, 'installment_earning', { rental: rental._id, note });
  await platformFee(fee, { rental: rental._id, note });
}

module.exports = {
  feeFor,
  credit,
  debit,
  holdForJob,
  releaseJob,
  refundJob,
  holdForRental,
  refundRental,
  settleRental,
  payInstallment
};
