const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const { authRequired, optionalAuth, requireRole } = require('../middleware/auth');
const { validate, discardUploads } = require('../middleware/validate');
const upload = require('../middleware/upload');
const realtime = require('../utils/realtime');
const { point, latLng, distanceKm, round1, nearestArea, validLat, validLng } = require('../utils/geo');
const { nearbySearch, readNearby } = require('../services/nearby');
const { removeUpload } = require('../utils/files');
const { escapeRegex, paginate, setTotal, notFound, badRequest } = require('../utils/http');

const router = express.Router();

const withPresence = (json) => ({ ...json, online: realtime.isOnline(json.id) });
const me = (req) => withPresence(req.user.toPrivateJSON());

// --------------------------------------------------------------- account

router.get('/me', authRequired, (req, res) => res.json(me(req)));

const EDITABLE = ['name', 'phone', 'bio', 'city', 'address', 'headline', 'skills', 'hourlyRate', 'experienceYears', 'isAvailable', 'serviceRadiusKm'];

router.patch(
  '/me',
  authRequired,
  [
    body('name').optional().trim().isLength({ min: 2, max: 80 }).withMessage('Name must be at least 2 characters'),
    body('phone').optional().trim().isLength({ max: 30 }),
    body('bio').optional().isString().isLength({ max: 1000 }).withMessage('Bio is too long (max 1000 characters)'),
    body('city').optional().trim().isLength({ max: 60 }),
    body('address').optional().trim().isLength({ max: 300 }).withMessage('Address is too long (max 300 characters)'),
    body('headline').optional().trim().isLength({ max: 100 }),
    body('skills').optional().isArray({ max: 20 }).withMessage('Skills must be a list (max 20)'),
    body('skills.*').optional().isString().trim().isLength({ min: 1, max: 40 }),
    body('hourlyRate').optional().isFloat({ min: 0, max: 100000 }).toFloat(),
    body('experienceYears').optional().isInt({ min: 0, max: 60 }).toInt(),
    body('isAvailable').optional().isBoolean().toBoolean(),
    body('serviceRadiusKm').optional().isInt({ min: 1, max: 100 }).withMessage('Travel distance must be 1–100 km').toInt(),
    body('lat').optional({ values: 'null' }).isFloat({ min: -90, max: 90 }).withMessage('Invalid location').toFloat(),
    body('lng').optional({ values: 'null' }).isFloat({ min: -180, max: 180 }).withMessage('Invalid location').toFloat(),
    body('area').optional().isString().trim().isLength({ max: 60 }),
    body('clearLocation').optional().isBoolean().toBoolean()
  ],
  validate,
  async (req, res) => {
    for (const key of EDITABLE) {
      if (req.body[key] !== undefined) req.user[key] = req.body[key];
    }
    // Location: { lat, lng, area? } sets it (the area is filled in from the
    // nearest known neighbourhood when not given); { clearLocation: true } removes it.
    const locationChanged = await applyLocation(req.user, req.body);
    if (Array.isArray(req.body.skills)) {
      req.user.skills = [...new Set(req.body.skills.map((s) => String(s).trim().toLowerCase()).filter(Boolean))];
    }
    await req.user.save();
    if (locationChanged && req.user.role === 'supplier') {
      // A supplier's tools are wherever their shop is.
      const update = req.user.geo ? { $set: { geo: req.user.geo, area: req.user.area } } : { $unset: { geo: 1 }, $set: { area: '' } };
      await Tool.updateMany({ supplier: req.user._id }, update);
    }
    res.json(me(req));
  }
);

async function applyLocation(user, src) {
  if (src.clearLocation) {
    user.geo = undefined;
    user.area = '';
    return true;
  }
  const hasLat = src.lat !== undefined && src.lat !== null;
  const hasLng = src.lng !== undefined && src.lng !== null;
  if (hasLat !== hasLng) throw badRequest('Send both lat and lng');
  if (hasLat) {
    if (!validLat(src.lat) || !validLng(src.lng)) throw badRequest('Invalid location');
    user.geo = point(src.lat, src.lng);
    const near = nearestArea(src.lat, src.lng);
    user.area = src.area !== undefined ? src.area : near ? near.name : '';
    if (near && !user.city) user.city = near.city;
    return true;
  }
  if (src.area !== undefined) {
    user.area = src.area;
    return true;
  }
  return false;
}

router.post('/me/avatar', authRequired, upload.single('avatar'), async (req, res) => {
  if (!req.file) throw badRequest('Attach an image in the "avatar" field');
  removeUpload(req.user.avatar);
  req.user.avatar = req.file.filename;
  await req.user.save();
  res.json(me(req));
});

// Technician portfolio: photos of past work shown on the public profile.
router.post('/me/portfolio', authRequired, requireRole('technician'), upload.array('images', User.PORTFOLIO_MAX), async (req, res) => {
  const added = (req.files || []).map((f) => f.filename);
  if (!added.length) throw badRequest('Attach at least one photo in the "images" field');
  const room = User.PORTFOLIO_MAX - req.user.portfolio.length;
  if (added.length > room) {
    discardUploads(req);
    throw badRequest(`A portfolio holds up to ${User.PORTFOLIO_MAX} photos. Remove one first.`);
  }
  req.user.portfolio.push(...added);
  await req.user.save();
  res.status(201).json(me(req));
});

router.delete('/me/portfolio/:file', authRequired, requireRole('technician'), async (req, res) => {
  if (!req.user.portfolio.includes(req.params.file)) throw notFound('Photo not found');
  req.user.portfolio = req.user.portfolio.filter((f) => f !== req.params.file);
  await req.user.save();
  removeUpload(req.params.file);
  res.json(me(req));
});

// ------------------------------------------------------------- favourites

router.get('/me/favorites', authRequired, async (req, res) => {
  const [technicians, tools] = await Promise.all([
    User.find({ _id: { $in: req.user.favoriteTechnicians }, role: 'technician', status: { $ne: 'suspended' } }),
    Tool.find({ _id: { $in: req.user.favoriteTools } }).populate('supplier', 'name avatar city kycStatus')
  ]);
  res.json({ technicians: technicians.map((t) => withPresence(t.toProfileJSON())), tools });
});

// Saves or un-saves a technician or tool. Body: { type, id, saved? } —
// without `saved` it toggles.
router.post(
  '/me/favorites',
  authRequired,
  [
    body('type').isIn(['technician', 'tool']).withMessage('type must be technician or tool'),
    body('id').isMongoId().withMessage('Invalid id'),
    body('saved').optional().isBoolean().toBoolean()
  ],
  validate,
  async (req, res) => {
    const { type, id } = req.body;
    const field = type === 'tool' ? 'favoriteTools' : 'favoriteTechnicians';
    const exists =
      type === 'tool' ? await Tool.exists({ _id: id }) : await User.exists({ _id: id, role: 'technician' });
    if (!exists) throw notFound(`That ${type} no longer exists`);

    const has = req.user[field].some((x) => String(x) === String(id));
    const saved = req.body.saved ?? !has;
    await User.updateOne({ _id: req.user._id }, saved ? { $addToSet: { [field]: id } } : { $pull: { [field]: id } });
    res.json({ type, id, saved });
  }
);

// --------------------------------------------------------------- summary

// One call that powers each role's dashboard.
router.get('/me/summary', authRequired, async (req, res) => {
  const id = req.user._id;
  const [unreadMessages, unreadNotifications] = await Promise.all([
    Message.countDocuments({ recipient: id, readAt: null }),
    Notification.countDocuments({ user: id, readAt: null })
  ]);
  const base = { unreadMessages, unreadNotifications, walletBalance: req.user.walletBalance };

  if (req.user.role === 'client') {
    const [byStatus, toConfirm, activeRentals, spentAgg] = await Promise.all([
      Job.aggregate([{ $match: { client: id } }, { $group: { _id: '$status', n: { $sum: 1 } } }]),
      Job.countDocuments({ client: id, status: 'in_progress', stage: 'done' }),
      Rental.countDocuments({ renter: id, status: { $in: ['requested', 'active'] } }),
      Job.aggregate([
        { $match: { client: id, status: 'completed' } },
        { $group: { _id: null, total: { $sum: { $ifNull: ['$agreedPrice', 0] } } } }
      ])
    ]);
    return res.json({
      ...base,
      jobs: Object.fromEntries(byStatus.map((s) => [s._id, s.n])),
      jobsToConfirm: toConfirm,
      activeRentals,
      spent: spentAgg[0]?.total || 0
    });
  }

  if (req.user.role === 'technician') {
    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);
    const [requests, activeJobs, completedAgg, monthAgg, pendingBids, inEscrow] = await Promise.all([
      Job.countDocuments({ requestedTechnician: id, status: 'pending', requestDeclined: false, 'bids.technician': { $ne: id } }),
      Job.countDocuments({ assignedTechnician: id, status: 'in_progress' }),
      Job.aggregate([
        { $match: { assignedTechnician: id, status: 'completed' } },
        { $group: { _id: null, n: { $sum: 1 }, earnings: { $sum: { $ifNull: ['$payment.net', '$agreedPrice'] } } } }
      ]),
      Job.aggregate([
        { $match: { assignedTechnician: id, status: 'completed', completedAt: { $gte: monthStart } } },
        { $group: { _id: null, earnings: { $sum: { $ifNull: ['$payment.net', '$agreedPrice'] } } } }
      ]),
      Job.countDocuments({ status: 'pending', bids: { $elemMatch: { technician: id, status: 'pending' } } }),
      Job.aggregate([
        { $match: { assignedTechnician: id, status: 'in_progress', 'payment.status': 'held' } },
        { $group: { _id: null, total: { $sum: '$payment.net' } } }
      ])
    ]);
    return res.json({
      ...base,
      requests,
      activeJobs,
      completedJobs: completedAgg[0]?.n || 0,
      earnings: completedAgg[0]?.earnings || 0,
      earningsThisMonth: monthAgg[0]?.earnings || 0,
      inEscrow: inEscrow[0]?.total || 0,
      pendingBids
    });
  }

  if (req.user.role === 'supplier') {
    const [tools, byStatus, revenueAgg] = await Promise.all([
      Tool.countDocuments({ supplier: id }),
      Rental.aggregate([{ $match: { supplier: id } }, { $group: { _id: '$status', n: { $sum: 1 } } }]),
      Rental.aggregate([
        { $match: { supplier: id, status: { $in: ['active', 'returned', 'completed'] } } },
        { $group: { _id: null, total: { $sum: '$totalCost' } } }
      ])
    ]);
    return res.json({ ...base, tools, rentals: Object.fromEntries(byStatus.map((s) => [s._id, s.n])), revenue: revenueAgg[0]?.total || 0 });
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
  res.json({ count: await Notification.countDocuments({ user: req.user._id, readAt: null }) });
});

router.post('/me/notifications/read-all', authRequired, async (req, res) => {
  const r = await Notification.updateMany({ user: req.user._id, readAt: null }, { $set: { readAt: new Date() } });
  res.json({ ok: true, updated: r.modifiedCount });
});

router.post('/me/notifications/:id/read', authRequired, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Notification not found');
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
//   ?lat=&lng=   search from this point (distances in the results)
//   ?radius=5    only within 5 km   ?covers=1 only those who travel that far
//   ?sort=distance (default when a location is given)
router.get('/technicians', optionalAuth, async (req, res) => {
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
  const nearby = readNearby(req.query);
  if (nearby) {
    const { items, total } = await nearbySearch(User, { ...nearby, filter: q, sort: sorts[sort] || sorts.rating, skip, limit });
    setTotal(res, total);
    return res.json(items.map(({ doc, km }) => withPresence({ ...doc.toProfileJSON(), distanceKm: km })));
  }
  const [techs, total] = await Promise.all([
    User.find(q).sort(sorts[sort] || sorts.rating).skip(skip).limit(limit),
    User.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(techs.map((t) => withPresence(t.toProfileJSON())));
});

router.get('/:id', optionalAuth, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('User not found');
  const user = await User.findById(req.params.id);
  if (!user) throw notFound('User not found');
  // Visitors only see the marketplace's public faces: technicians and suppliers.
  if (!req.user && !['technician', 'supplier'].includes(user.role)) throw notFound('User not found');
  const full = req.user && (String(user._id) === String(req.user._id) || req.user.role === 'admin');
  const json = withPresence(full ? user.toPrivateJSON() : user.toProfileJSON());
  // How far they are from the viewer (?lat=&lng=, or the viewer's saved location).
  const from = readNearby(req.query, req.user && latLng(req.user.geo));
  if (from && !full) json.distanceKm = round1(distanceKm(from.near, latLng(user.geo)));
  res.json(json);
});

module.exports = router;
