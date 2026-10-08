const express = require('express');
const Job = require('../models/Job');
const User = require('../models/User');
const { authRequired, requireRole } = require('../middleware/auth');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { rankTechnicians } = require('../utils/ai');
const upload = require('../middleware/upload');

const router = express.Router();

// List jobs — filtered by role and query params.
router.get('/', authRequired, async (req, res) => {
  const { status, mine } = req.query;
  const q = {};
  if (status) q.status = status;
  if (req.user.role === 'client' && mine === '1') q.client = req.user._id;
  if (req.user.role === 'technician') {
    if (mine === '1') q.assignedTechnician = req.user._id;
    else if (!status) q.status = 'pending';
  }
  const jobs = await Job.find(q)
    .populate('client', 'name email rating')
    .populate('assignedTechnician', 'name email rating')
    .sort({ createdAt: -1 });
  res.json(jobs);
});

// Create a job (client). Accepts multipart/form-data so the client can
// attach up to 5 photos (field name "images") alongside the text fields.
router.post('/', authRequired, requireRole('client'), upload.array('images', 5), async (req, res) => {
  const { title, description, category, budget, location } = req.body;
  if (!title || !description) return res.status(400).json({ error: 'title and description required' });
  const images = (req.files || []).map((f) => f.filename);
  const job = await Job.create({
    client: req.user._id,
    title,
    description,
    category,
    budget: Number(budget) || 0,
    location,
    images
  });
  // Let every connected technician know there's fresh work to bid on.
  realtime.emitRole('technician', 'job:new', {
    jobId: job._id,
    title: job.title,
    category: job.category,
    budget: job.budget
  });
  res.status(201).json(job);
});

router.get('/:id', authRequired, async (req, res) => {
  const job = await Job.findById(req.params.id)
    .populate('client', 'name email phone rating')
    .populate('assignedTechnician', 'name email phone rating')
    .populate('bids.technician', 'name email rating jobsCompleted avgResponseMinutes skills');
  if (!job) return res.status(404).json({ error: 'Not found' });
  res.json(job);
});

// Place a bid (technician).
router.post('/:id/bids', authRequired, requireRole('technician'), async (req, res) => {
  const job = await Job.findById(req.params.id);
  if (!job) return res.status(404).json({ error: 'Not found' });
  if (job.status !== 'pending') return res.status(400).json({ error: 'Job not accepting bids' });
  if (job.bids.some((b) => String(b.technician) === String(req.user._id))) {
    return res.status(409).json({ error: 'You already placed a bid on this job' });
  }
  const { amount, message, etaDays } = req.body;
  if (typeof amount !== 'number' || amount <= 0) {
    return res.status(400).json({ error: 'amount must be a number greater than 0' });
  }
  job.bids.push({ technician: req.user._id, amount, message, etaDays });
  await job.save();
  await notify(job.client, 'bid', 'New bid on your job', `${req.user.name} bid ${amount}`, {
    jobId: job._id
  });
  realtime.emit(job.client, 'job:bid', {
    jobId: job._id,
    title: job.title,
    technicianName: req.user.name,
    amount
  });
  res.status(201).json(job);
});

// Cancel my own bid (technician). Only allowed while still pending.
router.delete('/:id/bids/me', authRequired, requireRole('technician'), async (req, res) => {
  const job = await Job.findById(req.params.id);
  if (!job) return res.status(404).json({ error: 'Not found' });
  const bid = job.bids.find((b) => String(b.technician) === String(req.user._id));
  if (!bid) return res.status(404).json({ error: 'No bid to cancel' });
  if (bid.status !== 'pending') {
    return res.status(400).json({ error: 'Only pending bids can be cancelled' });
  }
  job.bids.id(bid._id).deleteOne();
  await job.save();
  // Tell the client their bid count changed so their list/detail re-fetch,
  // and surface a toast via the standard notification path.
  await notify(job.client, 'bid', 'Bid withdrawn', `${req.user.name} withdrew their bid`, {
    jobId: job._id
  });
  realtime.emit(job.client, 'job:bid', {
    jobId: job._id,
    title: job.title,
    technicianName: req.user.name,
    cancelled: true
  });
  res.json({ ok: true });
});

// Accept a bid (client).
router.post(
  '/:id/accept/:bidId',
  authRequired,
  requireRole('client'),
  async (req, res) => {
    const job = await Job.findById(req.params.id);
    if (!job) return res.status(404).json({ error: 'Not found' });
    if (String(job.client) !== String(req.user._id)) return res.status(403).json({ error: 'Not your job' });
    const bid = job.bids.id(req.params.bidId);
    if (!bid) return res.status(404).json({ error: 'Bid not found' });
    bid.status = 'accepted';
    job.bids.forEach((b) => {
      if (String(b._id) !== String(bid._id)) b.status = 'rejected';
    });
    job.acceptedBid = bid._id;
    job.assignedTechnician = bid.technician;
    job.status = 'in_progress';
    await job.save();
    await User.updateOne({ _id: bid.technician }, { $inc: { jobsAssigned: 1 } });
    await notify(bid.technician, 'job_status', 'Bid accepted', `You were hired for "${job.title}"`, {
      jobId: job._id
    });
    realtime.emit(bid.technician, 'job:hired', {
      jobId: job._id,
      title: job.title,
      amount: bid.amount
    });
    res.json(job);
  }
);

// Update status.
router.patch('/:id/status', authRequired, async (req, res) => {
  const { status } = req.body;
  if (!Job.STATUSES.includes(status)) return res.status(400).json({ error: 'invalid status' });
  const job = await Job.findById(req.params.id);
  if (!job) return res.status(404).json({ error: 'Not found' });

  const isClient = String(job.client) === String(req.user._id);
  const isTech = String(job.assignedTechnician) === String(req.user._id);
  if (!isClient && !isTech && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Not allowed' });
  }

  job.status = status;
  if (status === 'completed') {
    job.completedAt = new Date();
    if (job.assignedTechnician) {
      await User.updateOne({ _id: job.assignedTechnician }, { $inc: { jobsCompleted: 1 } });
    }
  }
  await job.save();

  const notifyUser = isClient ? job.assignedTechnician : job.client;
  if (notifyUser) {
    await notify(notifyUser, 'job_status', `Job ${status}`, job.title, { jobId: job._id });
    realtime.emit(notifyUser, 'job:status', {
      jobId: job._id,
      title: job.title,
      status
    });
  }
  res.json(job);
});

// Rate completed job (client).
router.post('/:id/rate', authRequired, requireRole('client'), async (req, res) => {
  const { rating, review } = req.body;
  if (!rating || rating < 1 || rating > 5) return res.status(400).json({ error: 'rating 1-5' });
  const job = await Job.findById(req.params.id);
  if (!job) return res.status(404).json({ error: 'Not found' });
  if (String(job.client) !== String(req.user._id)) return res.status(403).json({ error: 'Not your job' });
  if (job.status !== 'completed') return res.status(400).json({ error: 'Job not completed' });
  if (job.rating) return res.status(409).json({ error: 'Already rated' });

  job.rating = rating;
  job.review = review || '';
  await job.save();

  const tech = await User.findById(job.assignedTechnician);
  if (tech) {
    const total = tech.rating * tech.ratingCount + rating;
    tech.ratingCount += 1;
    tech.rating = total / tech.ratingCount;
    await tech.save();
    await notify(tech._id, 'job_status', `New ${rating}★ rating`, review || job.title, { jobId: job._id });
    realtime.emit(tech._id, 'job:rated', {
      jobId: job._id,
      title: job.title,
      rating,
      review: review || ''
    });
  }
  res.json(job);
});

// AI-ranked bids — returns the job's bids sorted by technician score.
router.get('/:id/ranked-bids', authRequired, async (req, res) => {
  const job = await Job.findById(req.params.id).populate(
    'bids.technician',
    'name email rating ratingCount jobsCompleted jobsAssigned avgResponseMinutes skills'
  );
  if (!job) return res.status(404).json({ error: 'Not found' });

  const jobCategory = (job.category || '').toLowerCase();
  const techs = job.bids.map((b) => {
    const t = b.technician || {};
    const completionRate = t.jobsAssigned ? t.jobsCompleted / t.jobsAssigned : 0;
    const responseSpeed = 1 / (1 + (t.avgResponseMinutes || 60) / 60);
    const skills = (t.skills || []).map((s) => String(s).toLowerCase());
    const skillMatch = jobCategory && skills.includes(jobCategory) ? 1 : 0;
    return {
      bidId: b._id,
      technicianId: t._id,
      name: t.name,
      amount: b.amount,
      etaDays: b.etaDays,
      message: b.message,
      rating: t.rating || 0,
      ratingCount: t.ratingCount || 0,
      jobsCompleted: t.jobsCompleted || 0,
      completionRate,
      responseSpeed,
      avgResponseMinutes: t.avgResponseMinutes || 60,
      skills,
      skillMatch
    };
  });

  const ranked = await rankTechnicians(techs, { jobCategory });
  res.json(ranked);
});

module.exports = router;