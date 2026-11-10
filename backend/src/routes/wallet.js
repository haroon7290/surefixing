// The user's sandbox wallet: balance, history, demo top-ups and payouts.
// No real money moves anywhere — see services/wallet.js.
const express = require('express');
const { body } = require('express-validator');
const Transaction = require('../models/Transaction');
const Job = require('../models/Job');
const Rental = require('../models/Rental');
const User = require('../models/User');
const config = require('../config');
const wallet = require('../services/wallet');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { paginate, setTotal, badRequest } = require('../utils/http');

const router = express.Router();
router.use(authRequired);

const sum = (rows) => rows[0]?.total || 0;

// Balance, money currently in escrow (paid in by me / waiting to be paid to
// me), and the latest transactions.
router.get('/', async (req, res) => {
  const id = req.user._id;
  const [jobsHeld, rentalsHeld, jobsIncoming, rentalsIncoming, recent] = await Promise.all([
    Job.aggregate([{ $match: { client: id, 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.amount' } } }]),
    Rental.aggregate([
      { $match: { renter: id, 'payment.status': 'held' } },
      { $group: { _id: null, total: { $sum: { $add: ['$payment.amount', '$payment.deposit'] } } } }
    ]),
    Job.aggregate([{ $match: { assignedTechnician: id, 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.net' } } }]),
    Rental.aggregate([{ $match: { supplier: id, 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.net' } } }]),
    Transaction.find({ user: id }).sort({ createdAt: -1 }).limit(10).populate('job', 'title').populate({ path: 'rental', select: 'tool', populate: { path: 'tool', select: 'name' } })
  ]);
  res.json({
    balance: req.user.walletBalance,
    held: sum(jobsHeld) + sum(rentalsHeld),
    incoming: sum(jobsIncoming) + sum(rentalsIncoming),
    feePercent: config.platformFeePercent,
    maxTopUp: config.wallet.maxTopUp,
    sandbox: true,
    recent
  });
});

router.get('/transactions', async (req, res) => {
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const q = { user: req.user._id };
  const [items, total] = await Promise.all([
    Transaction.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit).populate('job', 'title').populate({ path: 'rental', select: 'tool', populate: { path: 'tool', select: 'name' } }),
    Transaction.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(items);
});

const amountField = body('amount').isFloat({ min: 100 }).withMessage('Enter an amount of at least 100').toFloat();

// Adds demo funds.
router.post('/topup', [amountField], validate, async (req, res) => {
  const amount = Math.round(req.body.amount);
  if (amount > config.wallet.maxTopUp) throw badRequest(`You can add up to ${config.wallet.maxTopUp} at a time`);
  if (req.user.walletBalance + amount > config.wallet.maxBalance) throw badRequest('That would take your wallet over its limit');
  await wallet.credit(req.user._id, amount, 'topup', { note: 'Demo funds added' });
  const fresh = await User.findById(req.user._id).select('walletBalance');
  res.status(201).json({ balance: fresh.walletBalance });
});

// Demo payout: takes the money out of the wallet as if sent to a bank.
router.post('/withdraw', [amountField], validate, async (req, res) => {
  await wallet.debit(req.user._id, Math.round(req.body.amount), 'withdrawal', { note: 'Demo payout to bank' });
  const fresh = await User.findById(req.user._id).select('walletBalance');
  res.status(201).json({ balance: fresh.walletBalance });
});

module.exports = router;
