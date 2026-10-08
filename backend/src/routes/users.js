const express = require('express');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

router.get('/me', authRequired, (req, res) => {
  res.json(req.user.toPublicJSON());
});

router.patch('/me', authRequired, async (req, res) => {
  const allowed = ['name', 'phone', 'bio', 'skills', 'avatar'];
  for (const key of allowed) {
    if (req.body[key] !== undefined) req.user[key] = req.body[key];
  }
  await req.user.save();
  res.json(req.user.toPublicJSON());
});

router.get('/technicians', authRequired, async (_req, res) => {
  const techs = await User.find({ role: 'technician' }).select('-password');
  res.json(techs.map((t) => t.toPublicJSON()));
});

router.get('/:id', authRequired, async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) return res.status(404).json({ error: 'Not found' });
  res.json(user.toPublicJSON());
});

router.get('/me/notifications', authRequired, async (req, res) => {
  const items = await Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(50);
  res.json(items);
});

router.post('/me/notifications/:id/read', authRequired, async (req, res) => {
  await Notification.updateOne(
    { _id: req.params.id, user: req.user._id },
    { $set: { readAt: new Date() } }
  );
  res.json({ ok: true });
});

module.exports = router;
