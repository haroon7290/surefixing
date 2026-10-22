const express = require('express');
const catalog = require('../config/catalog');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');

const router = express.Router();

// Public: taxonomies the app needs before login (e.g. on the sign-up form).
router.get('/', (_req, res) => {
  res.json({
    serviceCategories: catalog.SERVICE_CATEGORIES,
    toolCategories: catalog.TOOL_CATEGORIES,
    urgencyLevels: catalog.URGENCY_LEVELS,
    toolConditions: catalog.TOOL_CONDITIONS,
    reportReasons: catalog.REPORT_REASONS
  });
});

// Public: headline numbers for the website's landing page. Cached briefly
// so a busy homepage doesn't run six counts per visit.
const STATS_TTL_MS = 60 * 1000;
let statsCache = null;

router.get('/stats', async (_req, res) => {
  if (statsCache && Date.now() - statsCache.at < STATS_TTL_MS) return res.json(statsCache.data);
  const active = { status: { $ne: 'suspended' } };
  const [technicians, verifiedTechnicians, jobsCompleted, tools, cities, rating] = await Promise.all([
    User.countDocuments({ role: 'technician', ...active }),
    User.countDocuments({ role: 'technician', kycStatus: 'approved', ...active }),
    Job.countDocuments({ status: 'completed' }),
    Tool.countDocuments({ available: true }),
    User.distinct('city', { role: 'technician', city: { $nin: ['', null] }, ...active }),
    Job.aggregate([{ $match: { rating: { $ne: null } } }, { $group: { _id: null, avg: { $avg: '$rating' }, n: { $sum: 1 } } }])
  ]);
  const data = {
    technicians,
    verifiedTechnicians,
    jobsCompleted,
    tools,
    cities: cities.length,
    averageRating: rating[0] ? Math.round(rating[0].avg * 10) / 10 : 0,
    reviews: rating[0]?.n || 0
  };
  statsCache = { at: Date.now(), data };
  res.json(data);
});

module.exports = router;
