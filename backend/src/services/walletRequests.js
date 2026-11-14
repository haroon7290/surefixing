// Deposits and withdrawals through the company's own accounts. Users ask,
// admins decide; every change of money still goes through services/wallet.js
// so the ledger stays exact.
const WalletRequest = require('../models/WalletRequest');
const User = require('../models/User');
const wallet = require('./wallet');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { badRequest, conflict, notFound } = require('../utils/http');

const money = (n) => `Rs ${Math.round(n).toLocaleString('en-US')}`;

function tellAdmins(request, user) {
  realtime.emitRole('admin', 'wallet:request', { requestId: request._id, kind: request.kind, amount: request.amount, name: user.name });
}

// The request moves from pending to `status` exactly once, even if two
// admins click at the same moment.
async function claim(id, status, admin, extra = {}) {
  const request = await WalletRequest.findOneAndUpdate(
    { _id: id, status: 'pending' },
    { $set: { status, reviewedBy: admin ? admin._id : null, reviewedAt: new Date(), ...extra } },
    { new: true }
  );
  if (request) return request;
  if (!(await WalletRequest.exists({ _id: id }))) throw notFound('Request not found');
  throw conflict('This request has already been handled');
}

async function deposit(user, { account, amount, transactionId, note, proofImage }) {
  const key = WalletRequest.normalizeTx(transactionId);
  if (key.length < 4) throw badRequest('Enter the transaction ID from your bank or wallet app');
  const used = await WalletRequest.exists({ kind: 'deposit', transactionKey: key, status: { $in: ['pending', 'approved'] } });
  if (used) throw conflict('This transaction ID has already been submitted');
  const request = await WalletRequest.create({
    user: user._id,
    kind: 'deposit',
    amount: Math.round(amount),
    companyAccount: account._id,
    sentTo: { method: account.kind, provider: account.provider, accountTitle: account.accountTitle, accountNumber: account.accountNumber },
    transactionId: String(transactionId).trim(),
    transactionKey: key,
    proofImage: proofImage || '',
    note: note || ''
  });
  tellAdmins(request, user);
  return request;
}

async function withdraw(user, { amount, payout, note }) {
  const value = Math.round(amount);
  const request = new WalletRequest({ user: user._id, kind: 'withdrawal', amount: value, payout, note: note || '' });
  // The money leaves the wallet now (402 if it isn't there).
  await wallet.debit(user._id, value, 'withdrawal', { note: `Withdrawal to ${payout.provider} · ${payout.accountNumber}` });
  try {
    await request.save();
  } catch (err) {
    await wallet.credit(user._id, value, 'withdrawal_reversed', { note: 'Withdrawal could not be created' });
    throw err;
  }
  await User.updateOne({ _id: user._id }, { $set: { payoutAccount: payout } });
  tellAdmins(request, user);
  return request;
}

// Withdrawal money that never left goes back to the wallet.
async function returnFunds(request, why) {
  if (request.kind !== 'withdrawal') return;
  await wallet.credit(request.user, request.amount, 'withdrawal_reversed', { note: why });
}

async function cancel(user, id) {
  const mine = await WalletRequest.findOne({ _id: id, user: user._id });
  if (!mine) throw notFound('Request not found');
  const request = await claim(id, 'cancelled', null);
  await returnFunds(request, 'Withdrawal cancelled');
  return request;
}

async function approve(admin, id, { amount, reference, note } = {}) {
  const current = await WalletRequest.findById(id);
  if (!current) throw notFound('Request not found');
  const extra = { adminNote: note || '' };
  // An admin may correct a deposit to the amount that actually arrived.
  if (current.kind === 'deposit' && amount) extra.amount = Math.round(amount);
  if (current.kind === 'withdrawal') extra.reference = reference || '';
  const request = await claim(id, 'approved', admin, extra);

  if (request.kind === 'deposit') {
    await wallet.credit(request.user, request.amount, 'deposit', { note: `${request.sentTo?.provider || 'Deposit'} · TX ${request.transactionId}` });
    await notify(request.user, 'wallet', 'Deposit approved', `${money(request.amount)} was added to your wallet.`, { requestId: request._id });
  } else {
    const to = request.payout ? `${request.payout.provider} · ${request.payout.accountNumber}` : 'your account';
    await notify(request.user, 'wallet', 'Withdrawal sent', `${money(request.amount)} was sent to ${to}.${request.reference ? ` Reference: ${request.reference}` : ''}`, {
      requestId: request._id
    });
  }
  return request;
}

async function reject(admin, id, reason) {
  const request = await claim(id, 'rejected', admin, { adminNote: reason || '' });
  await returnFunds(request, 'Withdrawal rejected — money returned');
  const what = request.kind === 'deposit' ? 'Deposit' : 'Withdrawal';
  const tail = request.kind === 'withdrawal' ? ` ${money(request.amount)} is back in your wallet.` : '';
  await notify(request.user, 'wallet', `${what} not approved`, `${reason || 'Please check the details and try again.'}${tail}`, { requestId: request._id });
  return request;
}

module.exports = { deposit, withdraw, cancel, approve, reject };
