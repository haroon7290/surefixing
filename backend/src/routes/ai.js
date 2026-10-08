// AI endpoints used by the app's "Smart Match" assistant and the post-job
// form. The heavy lifting happens in the Python service (ai-service/);
// utils/ai.js falls back to an in-process engine if it is offline.
const express = require('express');
const { body } = require('express-validator');
const User = require('../models/User');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const ai = require('../utils/ai');
const realtime = require('../utils/realtime');
const { URGENCY_LEVELS, serviceCategoryKeys } = require('../config/catalog');

const router = express.Router();

router.get('/status', authRequired, async (_req, res) => {
  res.json(await ai.status());
});

// Free-text problem → suggested category + urgency.
router.post(
  '/analyze',
  authRequired,
  [body('text').isString().trim().isLength({ min: 3, max: 3000 }).withMessage('Describe the problem in a few words')],
  validate,
  async (req, res) => {
    res.json(await ai.analyzeText(req.body.text));
  }
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
    body('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  validate,
  async (req, res) => {
    const { description = '', category, city, budget, urgency } = req.body;
    if (!description.trim() && !category) {
      return res.status(400).json({ error: 'Describe the problem or pick a category' });
    }
    const limit = req.body.limit || 10;

    const techs = await User.find({ role: 'technician', status: { $ne: 'suspended' } }).limit(500);
    const candidates = techs.map((t) => ({
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
    res.json({
      engine: result.engine,
      analysis,
      category: category || analysis?.category || 'general',
      urgency: urgency || analysis?.urgency || 'normal',
      total: result.ranked.length,
      ranked: result.ranked.slice(0, limit)
    });
  }
);

module.exports = router;
