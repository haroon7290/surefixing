const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const User = require('../models/User');
const Kyc = require('../models/Kyc');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const Report = require('../models/Report');
const { authRequired, requireRole } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { escapeRegex, paginate, setTotal, badRequest, notFound } = require('../utils/http');

const router = express.Router();
router.use(authRequired, requireRole('admin'));

const toMap = (rows) => Object.fromEntries(rows.map((r) => [r._id ?? 'unknown', r.n]));

function lastNDays(n) {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - (n - 1));
  return start;
}

function dailySeries(rows, start, n) {
  const byDay = Object.fromEntries(rows.map((r) => [r._id, r.n]));
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    return { date: key, count: byDay[key] || 0 };
  });
}

const perDay = (Model, start) =>
  Model.aggregate([
    { $match: { createdAt: { $gte: start } } },
    { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, n: { $sum: 1 } } }
  ]);

router.get('/stats', async (_req, res) => {
  const start = lastNDays(7);
  const [
    users,
    jobs,
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
    jobsDaily
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
    Rental.aggregate([
      { $match: { status: { $in: ['active', 'returned', 'completed'] } } },
      { $group: { _id: null, total: { $sum: '$totalCost' } } }
    ]),
    User.aggregate([
      { $match: { role: 'technician', ratingCount: { $gt: 0 } } },
      { $group: { _id: null, avg: { $avg: '$rating' } } }
    ]),
    perDay(User, start),
    perDay(Job, start)
  ]);

  res.json({
    users,
    jobs,
    tools,
    rentals,
    pendingKyc,
    openReports,
    suspendedUsers: suspended,
    usersByRole: toMap(usersByRole),
    jobsByStatus: toMap(jobsByStatus),
    rentalsByStatus: toMap(rentalsByStatus),
    topCategories: topCategories.map((c) => ({ category: c._id || 'general', count: c.n })),
    jobsValue: jobsValue[0]?.total || 0,
    rentalsValue: rentalsValue[0]?.total || 0,
    avgTechnicianRating: techRating[0] ? Math.round(techRating[0].avg * 100) / 100 : 0,
    signupsLast7Days: dailySeries(signups, start, 7),
    jobsLast7Days: dailySeries(jobsDaily, start, 7)
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
  const [users, total] = await Promise.all([
    User.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit),
    User.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(users.map((u) => ({ ...u.toPublicJSON(), online: realtime.isOnline(u._id) })));
});

router.patch(
  '/users/:id/status',
  [body('status').isIn(['active', 'suspended']).withMessage('status must be active or suspended'), body('reason').optional().isString()],
  validate,
  async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) throw notFound('User not found');
    if (String(req.params.id) === String(req.user._id)) throw badRequest("You can't suspend your own account");
    const user = await User.findById(req.params.id);
    if (!user) throw notFound('User not found');
    user.status = req.body.status;
    await user.save();
    if (user.status === 'suspended') realtime.disconnectUser(user._id);
    else await notify(user._id, 'account', 'Account reactivated', 'Your SureFix account is active again.');
    res.json(user.toPublicJSON());
  }
);

router.delete('/users/:id', async (req, res) => {
  if (String(req.params.id) === String(req.user._id)) throw badRequest("You can't delete your own admin account");
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('User not found');
  realtime.disconnectUser(req.params.id);
  await User.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

// -------------------------------------------------------------------- KYC

router.get('/kyc', async (req, res) => {
  const q = {};
  if (req.query.status) q.status = req.query.status;
  const items = await Kyc.find(q).populate('user', 'name email role avatar city').sort({ status: -1, createdAt: -1 });
  res.json(items);
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
    if (!mongoose.isValidObjectId(req.params.id)) throw notFound();
    const kyc = await Kyc.findById(req.params.id);
    if (!kyc) throw notFound();
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
  const [jobs, total] = await Promise.all([
    Job.find(q)
      .populate('client', 'name email avatar')
      .populate('assignedTechnician', 'name email avatar')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Job.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(jobs);
});

router.get('/tools', async (req, res) => {
  const q = {};
  if (req.query.q) q.name = new RegExp(escapeRegex(String(req.query.q).trim()), 'i');
  const tools = await Tool.find(q).populate('supplier', 'name email').sort({ createdAt: -1 }).limit(200);
  res.json(tools);
});

// ---------------------------------------------------------------- reports

router.get('/reports', async (req, res) => {
  const q = {};
  if (req.query.status) q.status = req.query.status;
  const reports = await Report.find(q)
    .populate('reporter', 'name email role avatar')
    .populate('resolvedBy', 'name')
    .sort({ createdAt: -1 })
    .limit(200);
  res.json(reports);
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
    if (!mongoose.isValidObjectId(req.params.id)) throw notFound();
    const report = await Report.findById(req.params.id);
    if (!report) throw notFound();
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
