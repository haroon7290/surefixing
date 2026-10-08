// Reviews read model over Job data: what past clients said about a
// technician, plus a star distribution for the profile header.
const express = require('express');
const mongoose = require('mongoose');
const Job = require('../models/Job');
const { authRequired } = require('../middleware/auth');
const { paginate, setTotal, notFound } = require('../utils/http');

const router = express.Router();

function techId(req) {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Technician not found');
  return new mongoose.Types.ObjectId(req.params.id);
}

router.get('/technician/:id', authRequired, async (req, res) => {
  const id = techId(req);
  const filter = { assignedTechnician: id, rating: { $ne: null } };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const [jobs, total] = await Promise.all([
    Job.find(filter)
      .sort({ completedAt: -1, updatedAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('client', 'name avatar')
      .select('title category rating review completedAt updatedAt client'),
    Job.countDocuments(filter)
  ]);
  setTotal(res, total);
  res.json(
    jobs.map((j) => ({
      id: j._id,
      jobTitle: j.title,
      category: j.category,
      rating: j.rating,
      review: j.review || '',
      date: j.completedAt || j.updatedAt,
      clientName: j.client?.name || 'Client',
      clientAvatar: j.client?.avatar || ''
    }))
  );
});

router.get('/technician/:id/summary', authRequired, async (req, res) => {
  const id = techId(req);
  const rows = await Job.aggregate([
    { $match: { assignedTechnician: id, rating: { $ne: null } } },
    { $group: { _id: '$rating', n: { $sum: 1 } } }
  ]);
  const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  let count = 0;
  let sum = 0;
  rows.forEach((r) => {
    const star = Math.max(1, Math.min(5, Math.round(r._id)));
    distribution[star] += r.n;
    count += r.n;
    sum += r._id * r.n;
  });
  res.json({ count, average: count ? Math.round((sum / count) * 100) / 100 : 0, distribution });
});

module.exports = router;
