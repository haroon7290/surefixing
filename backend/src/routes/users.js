const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const upload = require('../middleware/upload');
const realtime = require('../utils/realtime');
const { escapeRegex, paginate, setTotal, notFound, badRequest } = require('../utils/http');

const router = express.Router();

const withPresence = (json) => ({ ...json, online: realtime.isOnline(json.id) });

router.get('/me', authRequired, (req, res) => {
  res.json(withPresence(req.user.toPublicJSON()));
});

router.patch(
  '/me',
  authRequired,
  [
    body('name').optional().trim().isLength({ min: 2, max: 80 }).withMessage('Name must be at least 2 characters'),
    body('phone').optional().trim().isLength({ max: 30 }),
    body('bio').optional().isString().isLength({ max: 1000 }).withMessage('Bio is too long (max 1000 characters)'),
    body('city').optional().trim().isLength({ max: 60 }),
    body('headline').optional().trim().isLength({ max: 100 }),
    body('skills').optional().isArray({ max: 20 }).withMessage('Skills must be a list (max 20)'),
    body('skills.*').optional().isString().trim().isLength({ min: 1, max: 40 }),
    body('hourlyRate').optional().isFloat({ min: 0, max: 100000 }).toFloat(),
    body('experienceYears').optional().isInt({ min: 0, max: 60 }).toInt(),
    body('isAvailable').optional().isBoolean().toBoolean()
  ],
  validate,
  async (req, res) => {
    const allowed = ['name', 'phone', 'bio', 'city', 'headline', 'skills', 'hourlyRate', 'experienceYears', 'isAvailable'];
    for (const key of allowed) {
      if (req.body[key] !== undefined) req.user[key] = req.body[key];
    }
    if (Array.isArray(req.body.skills)) {
      req.user.skills = [...new Set(req.body.skills.map((s) => String(s).trim().toLowerCase()).filter(Boolean))];
    }
    await req.user.save();
    res.json(withPresence(req.user.toPublicJSON()));
  }
);

router.post('/me/avatar', authRequired, upload.single('avatar'), async (req, res) => {
  if (!req.file) throw badRequest('Attach an image in the "avatar" field');
  req.user.avatar = req.file.filename;
  await req.user.save();
  res.json(withPresence(req.user.toPublicJSON()));
});

// One call that powers each role's dashboard.
router.get('/me/summary', authRequired, async (req, res) => {
  const me = req.user._id;
  const unreadMessages = await Message.countDocuments({ recipient: me, readAt: null });
  const unreadNotifications = await Notification.countDocuments({ user: me, readAt: null });
  const base = { unreadMessages, unreadNotifications };

  if (req.user.role === 'client') {
    const [byStatus, rentals] = await Promise.all([
      Job.aggregate([{ $match: { client: me } }, { $group: { _id: '$status', n: { $sum: 1 } } }]),
      Rental.countDocuments({ renter: me, status: { $in: ['requested', 'active'] } })
    ]);
    const jobs = Object.fromEntries(byStatus.map((s) => [s._id, s.n]));
    return res.json({ ...base, jobs, activeRentals: rentals });
  }

  if (req.user.role === 'technician') {
    const [requests, active, completedAgg, pendingBids] = await Promise.all([
      Job.countDocuments({ requestedTechnician: me, status: 'pending', requestDeclined: false, 'bids.technician': { $ne: me } }),
      Job.countDocuments({ assignedTechnician: me, status: 'in_progress' }),
      Job.aggregate([
        { $match: { assignedTechnician: me, status: 'completed' } },
        { $group: { _id: null, n: { $sum: 1 }, earnings: { $sum: { $ifNull: ['$agreedPrice', 0] } } } }
      ]),
      Job.countDocuments({ status: 'pending', bids: { $elemMatch: { technician: me, status: 'pending' } } })
    ]);
    return res.json({
      ...base,
      requests,
      activeJobs: active,
      completedJobs: completedAgg[0]?.n || 0,
      earnings: completedAgg[0]?.earnings || 0,
      pendingBids
    });
  }

  if (req.user.role === 'supplier') {
    const toolIds = (await Tool.find({ supplier: me }).select('_id')).map((t) => t._id);
    const [byStatus, revenueAgg] = await Promise.all([
      Rental.aggregate([{ $match: { tool: { $in: toolIds } } }, { $group: { _id: '$status', n: { $sum: 1 } } }]),
      Rental.aggregate([
        { $match: { tool: { $in: toolIds }, status: { $in: ['active', 'returned', 'completed'] } } },
        { $group: { _id: null, total: { $sum: '$totalCost' } } }
      ])
    ]);
    const rentals = Object.fromEntries(byStatus.map((s) => [s._id, s.n]));
    return res.json({ ...base, tools: toolIds.length, rentals, revenue: revenueAgg[0]?.total || 0 });
  }

  res.json(base);
});

// ---------------------------------------------------------- notifications

router.get('/me/notifications', authRequired, async (req, res) => {
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const q = { user: req.user._id };
  if (req.query.unread === '1') q.readAt = null;
  const [items, total] = await Promise.all([
    Notification.find(q).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Notification.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(items);
});

router.get('/me/notifications/unread-count', authRequired, async (req, res) => {
  const count = await Notification.countDocuments({ user: req.user._id, readAt: null });
  res.json({ count });
});

router.post('/me/notifications/read-all', authRequired, async (req, res) => {
  const r = await Notification.updateMany({ user: req.user._id, readAt: null }, { $set: { readAt: new Date() } });
  res.json({ ok: true, updated: r.modifiedCount });
});

router.post('/me/notifications/:id/read', authRequired, async (req, res) => {
  await Notification.updateOne({ _id: req.params.id, user: req.user._id }, { $set: { readAt: new Date() } });
  res.json({ ok: true });
});

// ------------------------------------------------------------ discovery

// Technician directory with search, filters, sorting and pagination.
//   ?q=        name / headline / skills / bio text
//   ?category= skill key (e.g. plumbing)
//   ?city=     exact city (case-insensitive)
//   ?minRating=4  ?available=1  ?verified=1
//   ?sort=rating|jobs|price|newest   ?page= ?limit=
router.get('/technicians', authRequired, async (req, res) => {
  const q = { role: 'technician', status: { $ne: 'suspended' } };
  const { q: text, category, city, minRating, available, verified, sort } = req.query;
  if (text) {
    const rx = new RegExp(escapeRegex(String(text).trim()), 'i');
    q.$or = [{ name: rx }, { headline: rx }, { skills: rx }, { bio: rx }];
  }
  if (category) q.skills = String(category).toLowerCase();
  if (city) q.city = new RegExp(`^${escapeRegex(String(city).trim())}$`, 'i');
  if (minRating) q.rating = { $gte: Number(minRating) || 0 };
  if (available === '1') q.isAvailable = { $ne: false };
  if (verified === '1') q.kycStatus = 'approved';

  const sorts = {
    rating: { rating: -1, ratingCount: -1 },
    jobs: { jobsCompleted: -1 },
    price: { hourlyRate: 1 },
    newest: { createdAt: -1 }
  };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const [techs, total] = await Promise.all([
    User.find(q).sort(sorts[sort] || sorts.rating).skip(skip).limit(limit),
    User.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(techs.map((t) => withPresence(t.toProfileJSON())));
});

router.get('/:id', authRequired, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound();
  const user = await User.findById(req.params.id);
  if (!user) throw notFound();
  const self = String(user._id) === String(req.user._id);
  const json = self || req.user.role === 'admin' ? user.toPublicJSON() : user.toProfileJSON();
  res.json(withPresence(json));
});

module.exports = router;
