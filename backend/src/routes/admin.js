const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const User = require('../models/User');
const Kyc = require('../models/Kyc');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const Report = require('../models/Report');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const Transaction = require('../models/Transaction');
const WalletRequest = require('../models/WalletRequest');
const PaymentAccount = require('../models/PaymentAccount');
const walletRequests = require('../services/walletRequests');
const config = require('../config');
const { authRequired, requireRole } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { removeUpload } = require('../utils/files');
const jobs = require('../services/jobs');
const wallet = require('../services/wallet');
const { escapeRegex, paginate, setTotal, badRequest, notFound } = require('../utils/http');
const firebase = require('../utils/firebase');

const router = express.Router();
router.use(authRequired, requireRole('admin'));

const toMap = (rows) => Object.fromEntries(rows.map((r) => [r._id ?? 'unknown', r.n]));
const total = (rows) => rows[0]?.total || 0;

function lastNDays(n) {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - (n - 1));
  return start;
}

function dailySeries(rows, start, n, field = 'n') {
  const byDay = Object.fromEntries(rows.map((r) => [r._id, r[field]]));
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    return { date: key, count: byDay[key] || 0 };
  });
}

const day = { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } };
const perDay = (Model, start) => Model.aggregate([{ $match: { createdAt: { $gte: start } } }, { $group: { _id: day, n: { $sum: 1 } } }]);

async function loadById(Model, id, label) {
  if (!mongoose.isValidObjectId(id)) throw notFound(`${label} not found`);
  const doc = await Model.findById(id);
  if (!doc) throw notFound(`${label} not found`);
  return doc;
}

// -------------------------------------------------------------- overview

router.get('/stats', async (_req, res) => {
  const start = lastNDays(7);
  const [
    users,
    jobCount,
    tools,
    rentals,
    pendingKyc,
    openReports,
    suspended,
    usersByRole,
    jobsByStatus,
    rentalsByStatus,
    topCategories,
    jobsValue,
    rentalsValue,
    techRating,
    signups,
    jobsDaily,
    revenue,
    revenueDaily,
    jobsEscrow,
    rentalsEscrow,
    paidBy,
    walletQueue
  ] = await Promise.all([
    User.countDocuments(),
    Job.countDocuments(),
    Tool.countDocuments(),
    Rental.countDocuments(),
    Kyc.countDocuments({ status: 'pending' }),
    Report.countDocuments({ status: 'open' }),
    User.countDocuments({ status: 'suspended' }),
    User.aggregate([{ $group: { _id: '$role', n: { $sum: 1 } } }]),
    Job.aggregate([{ $group: { _id: '$status', n: { $sum: 1 } } }]),
    Rental.aggregate([{ $group: { _id: '$status', n: { $sum: 1 } } }]),
    Job.aggregate([{ $group: { _id: '$category', n: { $sum: 1 } } }, { $sort: { n: -1 } }, { $limit: 6 }]),
    Job.aggregate([{ $match: { status: 'completed' } }, { $group: { _id: null, total: { $sum: { $ifNull: ['$agreedPrice', 0] } } } }]),
    Rental.aggregate([{ $match: { status: { $in: ['active', 'returned', 'completed'] } } }, { $group: { _id: null, total: { $sum: { $subtract: ['$totalCost', { $ifNull: ['$earlyRefund', 0] }] } } } }]),
    User.aggregate([{ $match: { role: 'technician', ratingCount: { $gt: 0 } } }, { $group: { _id: null, avg: { $avg: '$rating' } } }]),
    perDay(User, start),
    perDay(Job, start),
    Transaction.aggregate([{ $match: { type: 'platform_fee' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
    Transaction.aggregate([{ $match: { type: 'platform_fee', createdAt: { $gte: start } } }, { $group: { _id: day, total: { $sum: '$amount' } } }]),
    Job.aggregate([{ $match: { 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.amount' } } }]),
    Rental.aggregate([{ $match: { 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: { $add: ['$payment.amount', '$payment.deposit'] } } } }]),
    Job.aggregate([{ $match: { status: 'completed' } }, { $group: { _id: '$payment.method', n: { $sum: 1 } } }]),
    WalletRequest.aggregate([{ $match: { status: 'pending' } }, { $group: { _id: '$kind', n: { $sum: 1 }, total: { $sum: '$amount' } } }])
  ]);
  const queue = (kind) => walletQueue.find((r) => r._id === kind) || { n: 0, total: 0 };

  res.json({
    users,
    jobs: jobCount,
    tools,
    rentals,
    pendingKyc,
    openReports,
    suspendedUsers: suspended,
    usersByRole: toMap(usersByRole),
    jobsByStatus: toMap(jobsByStatus),
    rentalsByStatus: toMap(rentalsByStatus),
    topCategories: topCategories.map((c) => ({ category: c._id || 'general', count: c.n })),
    jobsValue: total(jobsValue),
    rentalsValue: total(rentalsValue),
    platformRevenue: total(revenue),
    escrowHeld: total(jobsEscrow) + total(rentalsEscrow),
    feePercent: config.platformFeePercent,
    jobsPaidBy: toMap(paidBy),
    pendingDeposits: queue('deposit').n,
    pendingDepositsAmount: queue('deposit').total,
    pendingWithdrawals: queue('withdrawal').n,
    pendingWithdrawalsAmount: queue('withdrawal').total,
    avgTechnicianRating: techRating[0] ? Math.round(techRating[0].avg * 100) / 100 : 0,
    signupsLast7Days: dailySeries(signups, start, 7),
    jobsLast7Days: dailySeries(jobsDaily, start, 7),
    revenueLast7Days: dailySeries(revenueDaily, start, 7, 'total')
  });
});

// ------------------------------------------------------------------ users

// Open reports seen as disputes between two people: whoever raised it, and
// whoever it is about (the reported user, the tool's supplier, or the other
// people on the job). Returns userId -> [{ side, withName, withRole, ... }].
async function openDisputes() {
  const reports = await Report.find({ status: 'open' }).sort({ createdAt: -1 }).limit(500);
  const byUser = new Map();
  if (!reports.length) return byUser;
  const ids = (type) => reports.filter((r) => r.targetType === type).map((r) => r.targetId);
  const [tools, jobs] = await Promise.all([
    Tool.find({ _id: { $in: ids('tool') } }).select('supplier'),
    Job.find({ _id: { $in: ids('job') } }).select('client assignedTechnician number')
  ]);
  const toolOwner = new Map(tools.map((t) => [String(t._id), String(t.supplier)]));
  const jobById = new Map(jobs.map((j) => [String(j._id), j]));

  const sides = reports.map((r) => {
    const reporter = String(r.reporter);
    let against = [];
    if (r.targetType === 'user') against = [String(r.targetId)];
    if (r.targetType === 'tool' && toolOwner.has(String(r.targetId))) against = [toolOwner.get(String(r.targetId))];
    const job = r.targetType === 'job' ? jobById.get(String(r.targetId)) : null;
    if (job) against = [job.client, job.assignedTechnician].filter(Boolean).map(String);
    return { r, reporter, against: [...new Set(against)].filter((id) => id !== reporter), job };
  });
  const people = await User.find({ _id: { $in: [...new Set(sides.flatMap((s) => [s.reporter, ...s.against]))] } }).select('name role');
  const who = new Map(people.map((p) => [String(p._id), p]));

  const add = (userId, entry) => {
    if (!byUser.has(userId)) byUser.set(userId, []);
    byUser.get(userId).push(entry);
  };
  for (const { r, reporter, against, job } of sides) {
    const base = {
      reportId: r._id,
      reason: r.reason,
      targetType: r.targetType,
      about: r.targetLabel,
      jobNumber: job?.number || null,
      createdAt: r.createdAt
    };
    const other = against.map((id) => who.get(id)).filter(Boolean);
    add(reporter, { ...base, side: 'raised', withName: other.map((o) => o.name).join(', '), withRole: other[0]?.role || '' });
    const raiser = who.get(reporter);
    for (const id of against) add(id, { ...base, side: 'against', withName: raiser?.name || 'A user', withRole: raiser?.role || '' });
  }
  return byUser;
}

// ?role= ?status= ?q= ?dispute=1 (only people in an open dispute). Each user
// carries `disputes`: their open disputes and who they are with.
router.get('/users', async (req, res) => {
  const q = {};
  const disputes = await openDisputes();
  if (req.query.dispute === '1') q._id = { $in: [...disputes.keys()] };
  if (req.query.role) q.role = req.query.role;
  if (req.query.status) q.status = req.query.status;
  if (req.query.q) {
    const rx = new RegExp(escapeRegex(String(req.query.q).trim()), 'i');
    q.$or = [{ name: rx }, { email: rx }, { phone: rx }, { city: rx }];
  }
  const { limit, skip } = paginate(req, { defaultLimit: 100, maxLimit: 200 });
  const [users, count] = await Promise.all([User.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit), User.countDocuments(q)]);
  setTotal(res, count);
  res.json(users.map((u) => ({ ...u.toPrivateJSON(), online: realtime.isOnline(u._id), disputes: disputes.get(String(u._id)) || [] })));
});

router.patch(
  '/users/:id/status',
  [body('status').isIn(['active', 'suspended']).withMessage('status must be active or suspended')],
  validate,
  async (req, res) => {
    if (String(req.params.id) === String(req.user._id)) throw badRequest("You can't suspend your own account");
    const user = await loadById(User, req.params.id, 'User');
    user.status = req.body.status;
    await user.save();
    if (user.status === 'suspended') realtime.disconnectUser(user._id);
    else await notify(user._id, 'account', 'Account reactivated', 'Your SureFix account is active again.');
    res.json(user.toPrivateJSON());
  }
);

// Removes an account and everything that only exists because of it. Work in
// flight (a hired job, a tool out on rent) has to be finished or resolved
// first so nobody is left with a job or a payment hanging.
router.delete('/users/:id', async (req, res) => {
  if (String(req.params.id) === String(req.user._id)) throw badRequest("You can't delete your own admin account");
  const user = await loadById(User, req.params.id, 'User');
  const id = user._id;

  const [activeJobs, activeRentals, walletWaiting] = await Promise.all([
    Job.countDocuments({ status: 'in_progress', $or: [{ client: id }, { assignedTechnician: id }] }),
    Rental.countDocuments({ status: 'active', $or: [{ renter: id }, { supplier: id }] }),
    WalletRequest.countDocuments({ user: id, status: 'pending' })
  ]);
  if (activeJobs || activeRentals) {
    throw badRequest('This account has a job in progress or a tool out on rent. Resolve those first, or suspend the account instead.');
  }
  if (walletWaiting) throw badRequest('This account has a deposit or withdrawal waiting for review. Approve or reject it first.');

  realtime.disconnectUser(id);
  for (const job of await Job.find({ client: id, status: 'pending' })) {
    await jobs.cancel(job, req.user, 'The client account was removed');
  }
  await Job.updateMany({ status: 'pending', 'bids.technician': id }, { $pull: { bids: { technician: id } } });
  await Job.updateMany({ status: 'pending', requestedTechnician: id }, { $set: { requestDeclined: true } });
  for (const rental of await Rental.find({ status: 'requested', $or: [{ renter: id }, { supplier: id }] }).populate('tool', 'name')) {
    await wallet.refundRental(rental, rental.tool?.name || 'Tool');
    rental.status = 'cancelled';
    rental.rejectionReason = 'An account involved in this request was removed';
    await rental.save();
  }
  for (const tool of await Tool.find({ supplier: id })) {
    tool.images.forEach(removeUpload);
    await tool.deleteOne();
  }
  const kyc = await Kyc.findOneAndDelete({ user: id });
  [user.avatar, ...user.portfolio, kyc?.idFrontImage, kyc?.idBackImage, kyc?.selfieImage].forEach(removeUpload);
  await Promise.all([
    Notification.deleteMany({ user: id }),
    WalletRequest.deleteMany({ user: id }),
    Message.deleteMany({ $or: [{ sender: id }, { recipient: id }, { support: id }] }),
    User.updateMany({}, { $pull: { favoriteTechnicians: id } })
  ]);
  await user.deleteOne();
  await firebase.deleteUser(user.firebaseUid);
  res.json({ ok: true });
});

// -------------------------------------------------------------------- KYC

router.get('/kyc', async (req, res) => {
  const q = {};
  if (req.query.status) q.status = req.query.status;
  res.json(await Kyc.find(q).populate('user', 'name email role avatar city').sort({ status: -1, createdAt: -1 }));
});

router.post(
  '/kyc/:id/verify',
  [
    body('decision').isIn(['approved', 'rejected']).withMessage('decision must be approved or rejected'),
    body('reason').optional().isString().isLength({ max: 500 })
  ],
  validate,
  async (req, res) => {
    const { decision, reason } = req.body;
    const kyc = await loadById(Kyc, req.params.id, 'Verification');
    kyc.status = decision;
    kyc.rejectionReason = decision === 'rejected' ? reason || '' : '';
    await kyc.save();
    await User.updateOne({ _id: kyc.user }, { $set: { kycStatus: decision } });
    await notify(
      kyc.user,
      'kyc',
      decision === 'approved' ? 'You are verified!' : 'Verification rejected',
      decision === 'approved' ? 'Your profile now shows the verified badge.' : reason || 'Please resubmit your documents.',
      { kycId: kyc._id }
    );
    res.json(kyc);
  }
);

// -------------------------------------------------------- jobs & tools

router.get('/jobs', async (req, res) => {
  const q = {};
  if (req.query.status) q.status = req.query.status;
  if (req.query.q) {
    const rx = new RegExp(escapeRegex(String(req.query.q).trim()), 'i');
    q.$or = [{ title: rx }, { description: rx }];
    const number = Job.parseNumber(req.query.q);
    if (number) q.$or.push({ number });
  }
  const { limit, skip } = paginate(req, { defaultLimit: 100, maxLimit: 200 });
  const [items, count] = await Promise.all([
    Job.find(q)
      .populate('client', 'name email avatar')
      .populate('assignedTechnician', 'name email avatar')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Job.countDocuments(q)
  ]);
  setTotal(res, count);
  res.json(items);
});

// Settles a disputed job: `refund` cancels it and returns the escrow to the
// client; `release` completes it and pays the technician.
router.post(
  '/jobs/:id/resolve',
  [
    body('action').isIn(['refund', 'release']).withMessage('action must be refund or release'),
    body('note').optional().isString().isLength({ max: 500 }),
    body('technicianAtFault').optional().isBoolean().toBoolean()
  ],
  validate,
  async (req, res) => {
    const job = await loadById(Job, req.params.id, 'Job');
    const note = req.body.note || 'Resolved by SureFix support';
    if (req.body.action === 'refund') await jobs.cancel(job, req.user, note, { technicianAtFault: Boolean(req.body.technicianAtFault) });
    else await jobs.complete(job, req.user, note);
    res.json(job);
  }
);

router.get('/tools', async (req, res) => {
  const q = {};
  if (req.query.q) q.name = new RegExp(escapeRegex(String(req.query.q).trim()), 'i');
  res.json(await Tool.find(q).populate('supplier', 'name email').sort({ createdAt: -1 }).limit(200));
});

// --------------------------------------------------------------- payments

// Latest wallet movements across the platform. ?type=platform_fee etc.
// ---------------------------------------------------------- conversations
//
// Every chat between users (job and tool threads), read-only, so admins can
// see what was agreed when they resolve a dispute or a report. Support
// conversations are in the admin's own Messages inbox instead.

router.get('/conversations', async (req, res) => {
  const rows = await Message.aggregate([
    { $match: { support: null } },
    { $sort: { createdAt: -1 } },
    {
      $addFields: {
        a: { $cond: [{ $lt: ['$sender', '$recipient'] }, '$sender', '$recipient'] },
        b: { $cond: [{ $lt: ['$sender', '$recipient'] }, '$recipient', '$sender'] }
      }
    },
    { $group: { _id: { job: '$job', tool: '$tool', a: '$a', b: '$b' }, last: { $first: '$$ROOT' }, count: { $sum: 1 } } },
    { $sort: { 'last.createdAt': -1 } },
    { $limit: 500 }
  ]);
  const ids = (key) => [...new Set(rows.map((r) => r._id[key]).filter(Boolean).map(String))];
  const [users, jobsFound, tools] = await Promise.all([
    User.find({ _id: { $in: [...ids('a'), ...ids('b')] } }).select('name avatar role'),
    Job.find({ _id: { $in: ids('job') } }).select('number title status category'),
    Tool.find({ _id: { $in: ids('tool') } }).select('name category')
  ]);
  const userMap = new Map(users.map((u) => [String(u._id), u]));
  const jobMap = new Map(jobsFound.map((j) => [String(j._id), j]));
  const toolMap = new Map(tools.map((t) => [String(t._id), t]));
  const person = (id) => {
    const u = userMap.get(String(id));
    return u ? { id: u._id, name: u.name, avatar: u.avatar, role: u.role } : { id, name: 'Deleted account', avatar: '', role: '' };
  };
  const q = String(req.query.q || '').trim().toLowerCase();
  const out = rows
    .map((r) => {
      const job = r._id.job ? jobMap.get(String(r._id.job)) : null;
      const tool = r._id.tool ? toolMap.get(String(r._id.tool)) : null;
      return {
        kind: tool || r._id.tool ? 'tool' : 'job',
        jobId: r._id.job || null,
        toolId: r._id.tool || null,
        subject: job?.title || tool?.name || 'Removed',
        jobNumber: job?.number || null,
        jobStatus: job?.status || '',
        a: person(r._id.a),
        b: person(r._id.b),
        count: r.count,
        lastMessage: {
          sender: r.last.sender,
          senderName: person(r.last.sender).name,
          text: r.last.text,
          image: r.last.image,
          createdAt: r.last.createdAt
        }
      };
    })
    .filter((c) => {
      if (!q) return true;
      const number = Job.parseNumber(q);
      if (number && c.jobNumber === number) return true;
      return [c.a.name, c.b.name, c.subject, c.jobNumber ? `sf-${c.jobNumber}` : ''].some((x) => String(x).toLowerCase().includes(q));
    });
  res.json(out);
});

// One conversation: ?job= or ?tool=, plus the two people ?a= & ?b=.
router.get('/conversations/thread', async (req, res) => {
  const { job, tool, a, b } = req.query;
  if (![a, b].every((x) => mongoose.isValidObjectId(x))) throw badRequest('Choose the two people in the conversation');
  if (Boolean(job) === Boolean(tool) || !mongoose.isValidObjectId(job || tool)) throw badRequest('Choose a job or a tool');
  const scope = job ? { job } : { tool };
  const msgs = await Message.find({
    ...scope,
    $or: [
      { sender: a, recipient: b },
      { sender: b, recipient: a }
    ]
  })
    .sort({ createdAt: 1 })
    .limit(1000)
    .populate('sender', 'name');
  // Read-only: nothing is marked as read for the people talking.
  res.json(
    msgs.map((m) => ({
      _id: m._id,
      job: m.job,
      tool: m.tool,
      sender: m.sender?._id || m.sender,
      senderName: m.sender?.name || 'Deleted account',
      recipient: m.recipient,
      text: m.text,
      image: m.image,
      readAt: m.readAt,
      createdAt: m.createdAt
    }))
  );
});

router.get('/transactions', async (req, res) => {
  const q = {};
  if (req.query.type) q.type = req.query.type;
  const { limit, skip } = paginate(req, { defaultLimit: 100, maxLimit: 200 });
  const [items, count] = await Promise.all([
    Transaction.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit).populate('user', 'name role avatar')
      .populate('job', 'title number')
      .populate({ path: 'rental', select: 'tool number', populate: { path: 'tool', select: 'name' } }),
    Transaction.countDocuments(q)
  ]);
  setTotal(res, count);
  res.json(items);
});

// ------------------------------------------------- deposits & withdrawals

// ?kind=deposit|withdrawal ?status=pending (default) | approved | rejected | all
router.get('/wallet-requests', async (req, res) => {
  const q = {};
  if (['deposit', 'withdrawal'].includes(req.query.kind)) q.kind = req.query.kind;
  const status = req.query.status || 'pending';
  if (status !== 'all') q.status = { $in: String(status).split(',') };
  const { limit, skip } = paginate(req, { defaultLimit: 100, maxLimit: 200 });
  const [items, count] = await Promise.all([
    WalletRequest.find(q)
      .sort(status === 'pending' ? { createdAt: 1 } : { reviewedAt: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('user', 'name email phone role avatar walletBalance')
      .populate('reviewedBy', 'name'),
    WalletRequest.countDocuments(q)
  ]);
  setTotal(res, count);
  res.json(items);
});

// Deposit: { amount? (what actually arrived), note? } · Withdrawal: { reference?, note? }
router.post(
  '/wallet-requests/:id/approve',
  [
    body('amount').optional({ values: 'falsy' }).isFloat({ min: 1, max: 10000000 }).withMessage('Enter a valid amount').toFloat(),
    body('reference').optional().isString().trim().isLength({ max: 80 }),
    body('note').optional().isString().trim().isLength({ max: 300 })
  ],
  validate,
  async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Request not found');
    const request = await walletRequests.approve(req.user, req.params.id, req.body);
    res.json(await request.populate('user', 'name email phone role avatar walletBalance'));
  }
);

router.post(
  '/wallet-requests/:id/reject',
  [body('reason').isString().trim().isLength({ min: 3, max: 300 }).withMessage('Tell the user why')],
  validate,
  async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Request not found');
    const request = await walletRequests.reject(req.user, req.params.id, req.body.reason);
    res.json(await request.populate('user', 'name email phone role avatar walletBalance'));
  }
);

// Company accounts users send deposits to.
const accountFields = [
  body('kind').optional().isIn(['bank', 'mobile_wallet']).withMessage('Choose bank or mobile wallet'),
  body('provider').optional().isString().trim().isLength({ min: 2, max: 60 }).withMessage('Enter the bank or wallet name'),
  body('accountTitle').optional().isString().trim().isLength({ min: 2, max: 80 }).withMessage('Enter the account title'),
  body('accountNumber').optional().isString().trim().isLength({ min: 4, max: 40 }).withMessage('Enter the account number'),
  body('iban').optional().isString().trim().isLength({ max: 40 }),
  body('instructions').optional().isString().trim().isLength({ max: 300 }),
  body('active').optional().isBoolean().toBoolean(),
  body('order').optional().isInt({ min: 0, max: 1000 }).toInt()
];
const ACCOUNT_KEYS = ['kind', 'provider', 'accountTitle', 'accountNumber', 'iban', 'instructions', 'active', 'order'];
const pickAccount = (src) => Object.fromEntries(ACCOUNT_KEYS.filter((k) => src[k] !== undefined).map((k) => [k, src[k]]));

router.get('/payment-accounts', async (_req, res) => res.json(await PaymentAccount.find().sort({ order: 1, createdAt: 1 })));

router.post(
  '/payment-accounts',
  [
    body('provider').exists().withMessage('Enter the bank or wallet name'),
    body('accountTitle').exists().withMessage('Enter the account title'),
    body('accountNumber').exists().withMessage('Enter the account number'),
    ...accountFields
  ],
  validate,
  async (req, res) => res.status(201).json(await PaymentAccount.create(pickAccount(req.body)))
);

router.patch('/payment-accounts/:id', accountFields, validate, async (req, res) => {
  const account = await loadById(PaymentAccount, req.params.id, 'Account');
  Object.assign(account, pickAccount(req.body));
  await account.save();
  res.json(account);
});

// Accounts already used by deposits are hidden rather than deleted, so the
// history keeps making sense.
router.delete('/payment-accounts/:id', async (req, res) => {
  const account = await loadById(PaymentAccount, req.params.id, 'Account');
  if (await WalletRequest.exists({ companyAccount: account._id })) {
    account.active = false;
    await account.save();
    return res.json({ ok: true, hidden: true });
  }
  await account.deleteOne();
  res.json({ ok: true, hidden: false });
});

// ---------------------------------------------------------------- reports

router.get('/reports', async (req, res) => {
  const q = {};
  if (req.query.status) q.status = req.query.status;
  res.json(
    await Report.find(q).populate('reporter', 'name email role avatar').populate('resolvedBy', 'name').sort({ createdAt: -1 }).limit(200)
  );
});

router.post(
  '/reports/:id/resolve',
  [
    body('status').isIn(['resolved', 'dismissed']).withMessage('status must be resolved or dismissed'),
    body('note').optional().isString().isLength({ max: 1000 }),
    body('suspendUser').optional().isBoolean().toBoolean()
  ],
  validate,
  async (req, res) => {
    const report = await loadById(Report, req.params.id, 'Report');
    if (report.status !== 'open') throw badRequest('This report is already closed');
    report.status = req.body.status;
    report.resolutionNote = req.body.note || '';
    report.resolvedBy = req.user._id;
    report.resolvedAt = new Date();
    await report.save();

    if (req.body.suspendUser && report.targetType === 'user' && String(report.targetId) !== String(req.user._id)) {
      await User.updateOne({ _id: report.targetId }, { $set: { status: 'suspended' } });
      realtime.disconnectUser(report.targetId);
    }
    await notify(
      report.reporter,
      'report',
      'Report reviewed',
      report.status === 'resolved' ? 'Thanks — we took action on your report.' : 'We reviewed your report and found no violation.',
      { reportId: report._id }
    );
    res.json(report);
  }
);

module.exports = router;
