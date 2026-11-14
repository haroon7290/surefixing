// The user's wallet: balance, history, and money in and out through the
// company's accounts (deposits and withdrawals approved by an admin).
const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Transaction = require('../models/Transaction');
const Job = require('../models/Job');
const Rental = require('../models/Rental');
const PaymentAccount = require('../models/PaymentAccount');
const WalletRequest = require('../models/WalletRequest');
const config = require('../config');
const requests = require('../services/walletRequests');
const upload = require('../middleware/upload');
const { authRequired } = require('../middleware/auth');
const { validate, discardUploads } = require('../middleware/validate');
const { paginate, setTotal, badRequest, notFound } = require('../utils/http');

const router = express.Router();
router.use(authRequired);

const sum = (rows) => rows[0]?.total || 0;
const pendingSum = (user, kind) =>
  WalletRequest.aggregate([{ $match: { user, kind, status: 'pending' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]);

const withRefs = (query) =>
  query.populate('job', 'title').populate({ path: 'rental', select: 'tool', populate: { path: 'tool', select: 'name' } });

// Balance, money in escrow (paid in by me / waiting to be paid to me),
// deposits and withdrawals waiting for an admin, and the latest movements.
router.get('/', async (req, res) => {
  const id = req.user._id;
  const [jobsHeld, rentalsHeld, jobsIncoming, rentalsIncoming, deposits, withdrawals, recent] = await Promise.all([
    Job.aggregate([{ $match: { client: id, 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.amount' } } }]),
    Rental.aggregate([
      { $match: { renter: id, 'payment.status': 'held' } },
      { $group: { _id: null, total: { $sum: { $add: ['$payment.amount', '$payment.deposit'] } } } }
    ]),
    Job.aggregate([{ $match: { assignedTechnician: id, 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.net' } } }]),
    Rental.aggregate([{ $match: { supplier: id, 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.net' } } }]),
    pendingSum(id, 'deposit'),
    pendingSum(id, 'withdrawal'),
    withRefs(Transaction.find({ user: id }).sort({ createdAt: -1 }).limit(10))
  ]);
  res.json({
    balance: req.user.walletBalance,
    held: sum(jobsHeld) + sum(rentalsHeld),
    incoming: sum(jobsIncoming) + sum(rentalsIncoming),
    pendingDeposits: sum(deposits),
    pendingWithdrawals: sum(withdrawals),
    feePercent: config.platformFeePercent,
    minDeposit: config.wallet.minDeposit,
    maxDeposit: config.wallet.maxDeposit,
    minWithdrawal: config.wallet.minWithdrawal,
    payoutAccount: req.user.payoutAccount || null,
    recent
  });
});

router.get('/transactions', async (req, res) => {
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const q = { user: req.user._id };
  const [items, total] = await Promise.all([withRefs(Transaction.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit)), Transaction.countDocuments(q)]);
  setTotal(res, total);
  res.json(items);
});

// The company accounts to send deposits to.
router.get('/accounts', async (_req, res) => {
  res.json(await PaymentAccount.find({ active: true }).sort({ order: 1, createdAt: 1 }));
});

// My deposits and withdrawals, newest first. ?kind=deposit|withdrawal ?status=pending
router.get('/requests', async (req, res) => {
  const q = { user: req.user._id };
  if (['deposit', 'withdrawal'].includes(req.query.kind)) q.kind = req.query.kind;
  if (req.query.status) q.status = { $in: String(req.query.status).split(',') };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const [items, total] = await Promise.all([WalletRequest.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit), WalletRequest.countDocuments(q)]);
  setTotal(res, total);
  res.json(items);
});

// "I sent money to your account": multipart { accountId, amount,
// transactionId, note?, proof (screenshot, optional) }.
router.post(
  '/deposits',
  upload.single('proof'),
  [
    body('accountId').isMongoId().withMessage('Choose the account you sent the money to'),
    body('amount')
      .isFloat({ min: config.wallet.minDeposit, max: config.wallet.maxDeposit })
      .withMessage(`Enter an amount between ${config.wallet.minDeposit} and ${config.wallet.maxDeposit}`)
      .toFloat(),
    body('transactionId').isString().trim().isLength({ min: 4, max: 64 }).withMessage('Enter the transaction ID from your bank or wallet app'),
    body('note').optional().isString().isLength({ max: 300 })
  ],
  validate,
  async (req, res) => {
    try {
      const account = await PaymentAccount.findOne({ _id: req.body.accountId, active: true });
      if (!account) throw badRequest('That account is no longer available. Choose another one.');
      const waiting = await WalletRequest.countDocuments({ user: req.user._id, kind: 'deposit', status: 'pending' });
      if (waiting >= config.wallet.maxPendingDeposits) throw badRequest('You have several deposits waiting for review. Please wait for them to be checked.');
      const request = await requests.deposit(req.user, {
        account,
        amount: req.body.amount,
        transactionId: req.body.transactionId,
        note: req.body.note,
        proofImage: req.file ? req.file.filename : ''
      });
      res.status(201).json(request);
    } catch (err) {
      discardUploads(req);
      throw err;
    }
  }
);

// "Send my money to this account": { amount, method, provider, accountTitle, accountNumber, note? }
router.post(
  '/withdrawals',
  [
    body('amount').isFloat({ min: config.wallet.minWithdrawal }).withMessage(`You can withdraw ${config.wallet.minWithdrawal} or more`).toFloat(),
    body('method').isIn(WalletRequest.PAYOUT_METHODS).withMessage('Choose bank or mobile wallet'),
    body('provider').isString().trim().isLength({ min: 2, max: 60 }).withMessage('Enter your bank or wallet name'),
    body('accountTitle').isString().trim().isLength({ min: 2, max: 80 }).withMessage('Enter the account title'),
    body('accountNumber').isString().trim().isLength({ min: 4, max: 40 }).withMessage('Enter the account number or IBAN'),
    body('note').optional().isString().isLength({ max: 300 })
  ],
  validate,
  async (req, res) => {
    const { amount, method, provider, accountTitle, accountNumber, note } = req.body;
    const request = await requests.withdraw(req.user, { amount, payout: { method, provider, accountTitle, accountNumber }, note });
    res.status(201).json(request);
  }
);

// Take back a request the admin has not handled yet. A withdrawal's money
// returns to the wallet.
router.post('/requests/:id/cancel', async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Request not found');
  res.json(await requests.cancel(req.user, req.params.id));
});

module.exports = router;
