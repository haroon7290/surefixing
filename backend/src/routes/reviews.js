// Public-ish reviews endpoint: lists completed, rated jobs for a given
// technician so a client can see what past clients said before hiring them.
// Kept in its own file (rather than folded into users.js or jobs.js) since
// it's a distinct read model over Job data.
const express = require('express');
const Job = require('../models/Job');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.get('/technician/:id', authRequired, async (req, res) => {
  const jobs = await Job.find({
    assignedTechnician: req.params.id,
    rating: { $ne: null }
  })
    .sort({ completedAt: -1, updatedAt: -1 })
    .populate('client', 'name avatar')
    .select('title rating review completedAt updatedAt client');

  const reviews = jobs.map((j) => ({
    id: j._id,
    jobTitle: j.title,
    rating: j.rating,
    review: j.review || '',
    date: j.completedAt || j.updatedAt,
    clientName: j.client?.name || 'Client',
    clientAvatar: j.client?.avatar || ''
  }));

  res.json(reviews);
});

module.exports = router;