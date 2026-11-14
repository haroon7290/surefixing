// Public reference data and headline numbers for the app and the website.
const express = require('express');
const catalog = require('../config/catalog');
const { AREAS } = require('../config/areas');
const config = require('../config');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');

const router = express.Router();

// Taxonomies and marketplace rules the app needs before login.
router.get('/', (_req, res) => {
  res.json({
    serviceCategories: catalog.SERVICE_CATEGORIES.map(({ key, label }) => ({ key, label })),
    toolCategories: catalog.TOOL_CATEGORIES,
    urgencyLevels: catalog.URGENCY_LEVELS,
    toolConditions: catalog.TOOL_CONDITIONS,
    reportReasons: catalog.REPORT_REASONS,
    jobStages: catalog.JOB_STAGES,
    paymentMethods: catalog.PAYMENT_METHODS,
    platformFeePercent: config.platformFeePercent,
    autoConfirmHours: config.autoConfirmHours
  });
});

// A tiny cache so a busy homepage doesn't hit the database on every visit.
function cached(ttlMs, load) {
  let entry = null;
  return async () => {
    if (entry && Date.now() - entry.at < ttlMs) return entry.data;
    entry = { at: Date.now(), data: await load() };
    return entry.data;
  };
}

const stats = cached(60 * 1000, async () => {
  const active = { status: { $ne: 'suspended' } };
  const [technicians, verifiedTechnicians, jobsCompleted, tools, cities, rating] = await Promise.all([
    User.countDocuments({ role: 'technician', ...active }),
    User.countDocuments({ role: 'technician', kycStatus: 'approved', ...active }),
    Job.countDocuments({ status: 'completed' }),
    Tool.countDocuments({ available: true }),
    User.distinct('city', { role: 'technician', city: { $nin: ['', null] }, ...active }),
    Job.aggregate([{ $match: { rating: { $ne: null } } }, { $group: { _id: null, avg: { $avg: '$rating' }, n: { $sum: 1 } } }])
  ]);
  return {
    technicians,
    verifiedTechnicians,
    jobsCompleted,
    tools,
    cities: cities.length,
    averageRating: rating[0] ? Math.round(rating[0].avg * 10) / 10 : 0,
    reviews: rating[0]?.n || 0
  };
});

// Recent written 4–5★ reviews for the landing page. Clients appear by first
// name and initial only.
const testimonials = cached(5 * 60 * 1000, async () => {
  const rows = await Job.find({ rating: { $gte: 4 }, review: { $regex: /\S{3,}/ } })
    .sort({ completedAt: -1 })
    .limit(8)
    .populate('client', 'name city')
    .populate('assignedTechnician', 'name avatar')
    .select('title category rating review completedAt client assignedTechnician');
  return rows
    .filter((j) => j.client && j.assignedTechnician)
    .map((j) => {
      const [first, ...rest] = j.client.name.trim().split(/\s+/);
      return {
        rating: j.rating,
        review: j.review,
        category: j.category,
        jobTitle: j.title,
        date: j.completedAt,
        clientName: rest.length ? `${first} ${rest[rest.length - 1][0]}.` : first,
        clientCity: j.client.city || '',
        technicianId: j.assignedTechnician._id,
        technicianName: j.assignedTechnician.name,
        technicianAvatar: j.assignedTechnician.avatar || ''
      };
    });
});

// Neighbourhoods by city, for picking a location without GPS.
router.get('/areas', (_req, res) => res.json(AREAS));

router.get('/stats', async (_req, res) => res.json(await stats()));
router.get('/testimonials', async (_req, res) => res.json(await testimonials()));

module.exports = router;
