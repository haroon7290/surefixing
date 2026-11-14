// AI endpoints behind "Smart Match" and the post-job form. The heavy lifting
// happens in the Python service (ai-service/); utils/ai.js falls back to an
// in-process engine if it is offline.
const express = require('express');
const { body, query } = require('express-validator');
const User = require('../models/User');
const { authRequired, optionalAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const ai = require('../utils/ai');
const pricing = require('../services/pricing');
const { latLng, distanceKm, round1 } = require('../utils/geo');
const realtime = require('../utils/realtime');
const { URGENCY_LEVELS, serviceCategoryKeys } = require('../config/catalog');

const router = express.Router();

router.get('/status', optionalAuth, async (req, res) => {
  const s = await ai.status();
  // Only admins see the service address and error details.
  res.json(req.user?.role === 'admin' ? s : { online: s.online });
});

// Free-text problem → suggested category, urgency and a price estimate.
// Public: the website's "describe your problem" box works signed out.
router.post(
  '/analyze',
  optionalAuth,
  [body('text').isString().trim().isLength({ min: 3, max: 3000 }).withMessage('Describe the problem in a few words')],
  validate,
  async (req, res) => {
    const analysis = await ai.analyzeText(req.body.text);
    res.json({ ...analysis, estimate: await pricing.estimate(analysis.category, analysis.urgency) });
  }
);

// What jobs in a category usually cost: ?category=plumbing&urgency=high
router.get(
  '/estimate',
  optionalAuth,
  [
    query('category').isIn(serviceCategoryKeys).withMessage('Unknown category'),
    query('urgency').optional().isIn(URGENCY_LEVELS).withMessage('Unknown urgency')
  ],
  validate,
  async (req, res) => res.json(await pricing.estimate(req.query.category, req.query.urgency || 'normal'))
);

// Ranks every active technician for the client's described problem and
// explains each match. Body: {description, category?, city?, budget?, urgency?, limit?}
router.post(
  '/recommend',
  authRequired,
  [
    body('description').optional().isString().isLength({ max: 3000 }),
    body('category').optional({ values: 'falsy' }).isIn(serviceCategoryKeys).withMessage('Unknown category'),
    body('city').optional().isString().isLength({ max: 60 }),
    body('budget').optional({ values: 'falsy' }).isFloat({ min: 0 }).toFloat(),
    body('urgency').optional({ values: 'falsy' }).isIn(URGENCY_LEVELS),
    body('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
    body('lat').optional({ values: 'falsy' }).isFloat({ min: -90, max: 90 }).toFloat(),
    body('lng').optional({ values: 'falsy' }).isFloat({ min: -180, max: 180 }).toFloat()
  ],
  validate,
  async (req, res) => {
    const { description = '', category, city, budget, urgency } = req.body;
    if (!description.trim() && !category) {
      return res.status(400).json({ error: 'Describe the problem or pick a category' });
    }
    const limit = req.body.limit || 10;

    const techs = await User.find({ role: 'technician', status: { $ne: 'suspended' } }).limit(500);
    // Distance from where the work is (the location sent, else the client's own).
    const from = Number.isFinite(req.body.lat) && Number.isFinite(req.body.lng) ? { lat: req.body.lat, lng: req.body.lng } : latLng(req.user.geo);
    const candidates = techs.map((t) => ({
      ...(from && t.geo ? { distanceKm: round1(distanceKm(from, latLng(t.geo))) } : {}),
      serviceRadiusKm: t.serviceRadiusKm || 15,
      area: t.area || '',
      technicianId: String(t._id),
      name: t.name,
      avatar: t.avatar,
      headline: t.headline,
      bio: t.bio,
      skills: t.skills,
      city: t.city,
      hourlyRate: t.hourlyRate,
      experienceYears: t.experienceYears,
      isAvailable: t.isAvailable !== false,
      kycStatus: t.kycStatus,
      rating: t.rating || 0,
      ratingCount: t.ratingCount || 0,
      jobsCompleted: t.jobsCompleted || 0,
      jobsAssigned: t.jobsAssigned || 0,
      avgResponseMinutes: t.avgResponseMinutes || 60,
      online: realtime.isOnline(t._id)
    }));

    const result = await ai.recommendTechnicians(candidates, {
      description,
      category: category || '',
      city: city || req.user.city || '',
      budget: budget || 0,
      urgency: urgency || ''
    });
    const analysis = result.analysis || null;
    const finalCategory = category || analysis?.category || 'general';
    const finalUrgency = urgency || analysis?.urgency || 'normal';
    res.json({
      engine: result.engine,
      analysis,
      category: finalCategory,
      urgency: finalUrgency,
      estimate: await pricing.estimate(finalCategory, finalUrgency),
      total: result.ranked.length,
      ranked: result.ranked.slice(0, limit)
    });
  }
);

module.exports = router;
