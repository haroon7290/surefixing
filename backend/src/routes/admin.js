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
const config = require('../config');
const { authRequired, requireRole } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { removeUpload } = require('../utils/files');
const jobs = require('../services/jobs');
const wallet = require('../services/wallet');
const { escapeRegex, paginate, setTotal, badRequest, notFound } = require('../utils/http');

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
    paidBy
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
    Rental.aggregate([{ $match: { status: { $in: ['active', 'returned', 'completed'] } } }, { $group: { _id: null, total: { $sum: '$totalCost' } } }]),
    User.aggregate([{ $match: { role: 'technician', ratingCount: { $gt: 0 } } }, { $group: { _id: null, avg: { $avg: '$rating' } } }]),
    perDay(User, start),
    perDay(Job, start),
    Transaction.aggregate([{ $match: { type: 'platform_fee' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
    Transaction.aggregate([{ $match: { type: 'platform_fee', createdAt: { $gte: start } } }, { $group: { _id: day, total: { $sum: '$amount' } } }]),
    Job.aggregate([{ $match: { 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: '$payment.amount' } } }]),
    Rental.aggregate([{ $match: { 'payment.status': 'held' } }, { $group: { _id: null, total: { $sum: { $add: ['$payment.amount', '$payment.deposit'] } } } }]),
    Job.aggregate([{ $match: { status: 'completed' } }, { $group: { _id: '$payment.method', n: { $sum: 1 } } }])
  ]);

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
    avgTechnicianRating: techRating[0] ? Math.round(techRating[0].avg * 100) / 100 : 0,
    signupsLast7Days: dailySeries(signups, start, 7),
    jobsLast7Days: dailySeries(jobsDaily, start, 7),
    revenueLast7Days: dailySeries(revenueDaily, start, 7, 'total')
  });
});

// ------------------------------------------------------------------ users

router.get('/users', async (req, res) => {
  const q = {};
  if (req.query.role) q.role = req.query.role;
  if (req.query.status) q.status = req.query.status;
  if (req.query.q) {
    const rx = new RegExp(escapeRegex(String(req.query.q).trim()), 'i');
    q.$or = [{ name: rx }, { email: rx }, { phone: rx }, { city: rx }];
  }
  const { limit, skip } = paginate(req, { defaultLimit: 100, maxLimit: 200 });
  const [users, count] = await Promise.all([User.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit), User.countDocuments(q)]);
  setTotal(res, count);
  res.json(users.map((u) => ({ ...u.toPrivateJSON(), online: realtime.isOnline(u._id) })));
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

  const [activeJobs, activeRentals] = await Promise.all([
    Job.countDocuments({ status: 'in_progress', $or: [{ client: id }, { assignedTechnician: id }] }),
    Rental.countDocuments({ status: 'active', $or: [{ renter: id }, { supplier: id }] })
  ]);
  if (activeJobs || activeRentals) {
    throw badRequest('This account has a job in progress or a tool out on rent. Resolve those first, or suspend the account instead.');
  }

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
    Message.deleteMany({ $or: [{ sender: id }, { recipient: id }] }),
    User.updateMany({}, { $pull: { favoriteTechnicians: id } })
  ]);
  await user.deleteOne();
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
router.get('/transactions', async (req, res) => {
  const q = {};
  if (req.query.type) q.type = req.query.type;
  const { limit, skip } = paginate(req, { defaultLimit: 100, maxLimit: 200 });
  const [items, count] = await Promise.all([
    Transaction.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit).populate('user', 'name role avatar').populate('job', 'title'),
    Transaction.countDocuments(q)
  ]);
  setTotal(res, count);
  res.json(items);
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
