// Users flag a person, job or tool; admins work the queue in /api/admin/reports.
const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Report = require('../models/Report');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const realtime = require('../utils/realtime');
const { REPORT_REASONS } = require('../config/catalog');
const { badRequest, conflict, notFound } = require('../utils/http');

const router = express.Router();

const MODELS = {
  user: { model: User, label: (d) => `${d.name} (${d.role})` },
  job: { model: Job, label: (d) => d.title },
  tool: { model: Tool, label: (d) => d.name }
};

router.post(
  '/',
  authRequired,
  [
    body('targetType').isIn(Object.keys(MODELS)).withMessage('Invalid report target'),
    body('targetId').isMongoId().withMessage('Invalid report target'),
    body('reason').isIn(REPORT_REASONS).withMessage('Choose a reason'),
    body('details').optional().isString().isLength({ max: 1000 }).withMessage('Details are too long (max 1000 characters)')
  ],
  validate,
  async (req, res) => {
    const { targetType, targetId, reason, details } = req.body;
    if (targetType === 'user' && String(targetId) === String(req.user._id)) throw badRequest("You can't report yourself");
    const target = await MODELS[targetType].model.findById(new mongoose.Types.ObjectId(targetId));
    if (!target) throw notFound('The item you are reporting no longer exists');

    const dup = await Report.findOne({ reporter: req.user._id, targetType, targetId, status: 'open' });
    if (dup) throw conflict('You already reported this — our team is reviewing it');

    const report = await Report.create({
      reporter: req.user._id,
      targetType,
      targetId,
      targetLabel: MODELS[targetType].label(target),
      reason,
      details: details || ''
    });
    realtime.emitRole('admin', 'report:new', { reportId: report._id, targetType, reason });
    res.status(201).json(report);
  }
);

module.exports = router;
