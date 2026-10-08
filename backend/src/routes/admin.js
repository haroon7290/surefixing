const express = require('express');
const User = require('../models/User');
const Kyc = require('../models/Kyc');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const { authRequired, requireRole } = require('../middleware/auth');
const { notify } = require('../utils/notify');

const router = express.Router();
router.use(authRequired, requireRole('admin'));

router.get('/stats', async (_req, res) => {
  const [users, jobs, tools, pendingKyc] = await Promise.all([
    User.countDocuments(),
    Job.countDocuments(),
    Tool.countDocuments(),
    Kyc.countDocuments({ status: 'pending' })
  ]);
  res.json({ users, jobs, tools, pendingKyc });
});

router.get('/users', async (req, res) => {
  const q = {};
  if (req.query.role) q.role = req.query.role;
  const users = await User.find(q).sort({ createdAt: -1 });
  res.json(users.map((u) => u.toPublicJSON()));
});

router.delete('/users/:id', async (req, res) => {
  if (String(req.params.id) === String(req.user._id)) {
    return res.status(400).json({ error: "You can't delete your own admin account" });
  }
  await User.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

router.get('/kyc', async (req, res) => {
  const q = {};
  if (req.query.status) q.status = req.query.status;
  const items = await Kyc.find(q).populate('user', 'name email role').sort({ createdAt: -1 });
  res.json(items);
});

router.post('/kyc/:id/verify', async (req, res) => {
  const { decision, reason } = req.body;
  if (!['approved', 'rejected'].includes(decision)) {
    return res.status(400).json({ error: 'decision must be approved|rejected' });
  }
  const kyc = await Kyc.findById(req.params.id);
  if (!kyc) return res.status(404).json({ error: 'Not found' });
  kyc.status = decision;
  kyc.rejectionReason = decision === 'rejected' ? reason || '' : '';
  await kyc.save();
  await User.updateOne({ _id: kyc.user }, { $set: { kycStatus: decision } });
  await notify(kyc.user, 'kyc', `KYC ${decision}`, reason || '', { kycId: kyc._id });
  res.json(kyc);
});

router.get('/jobs', async (_req, res) => {
  const jobs = await Job.find()
    .populate('client', 'name email')
    .populate('assignedTechnician', 'name email')
    .sort({ createdAt: -1 });
  res.json(jobs);
});

module.exports = router;
