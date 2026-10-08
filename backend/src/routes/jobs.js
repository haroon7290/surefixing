const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Job = require('../models/Job');
const User = require('../models/User');
const { authRequired, requireRole } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const upload = require('../middleware/upload');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { rankTechnicians } = require('../utils/ai');
const { URGENCY_LEVELS, serviceCategoryKeys } = require('../config/catalog');
const { escapeRegex, paginate, setTotal, sameId, badRequest, forbidden, notFound, conflict } = require('../utils/http');

const router = express.Router();

const USER_CARD = 'name avatar rating ratingCount city kycStatus';
const CONTACT = 'phone email';
const BIDDER_FIELDS =
  'name avatar rating ratingCount jobsCompleted jobsAssigned avgResponseMinutes skills headline bio city kycStatus experienceYears isAvailable';

// Who may move a job from one status to another (besides admins).
const TRANSITIONS = {
  pending: { cancelled: ['client'] },
  in_progress: { completed: ['client', 'technician'], cancelled: ['client'] }
};

async function loadJob(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Job not found');
  const job = await Job.findById(id);
  if (!job) throw notFound('Job not found');
  return job;
}

function isOpenMarketJob(job) {
  return job.status === 'pending' && !job.requestedTechnician;
}

function canView(job, user) {
  if (user.role === 'admin' || sameId(job.client, user._id)) return true;
  if (user.role !== 'technician') return false;
  return (
    isOpenMarketJob(job) ||
    sameId(job.requestedTechnician, user._id) ||
    sameId(job.assignedTechnician, user._id) ||
    job.bids.some((b) => sameId(b.technician, user._id))
  );
}

// Strips phone/email unless the viewer is the other party on an assigned
// job (or an admin), so contact details are only shared after hiring.
function redactContacts(json, user) {
  const assigned = json.assignedTechnician && (json.status === 'in_progress' || json.status === 'completed');
  const isClient = sameId(json.client, user._id);
  const isTech = sameId(json.assignedTechnician, user._id);
  const showContacts = user.role === 'admin' || (assigned && (isClient || isTech));
  if (!showContacts) {
    for (const key of ['client', 'assignedTechnician', 'requestedTechnician']) {
      if (json[key] && typeof json[key] === 'object') {
        delete json[key].phone;
        delete json[key].email;
      }
    }
  }
  return json;
}

function populateJob(query) {
  return query
    .populate('client', `${USER_CARD} ${CONTACT}`)
    .populate('assignedTechnician', `${USER_CARD} ${CONTACT}`)
    .populate('requestedTechnician', USER_CARD)
    .populate('bids.technician', BIDDER_FIELDS);
}

// ------------------------------------------------------------------ list

router.get('/', authRequired, async (req, res) => {
  const { status, mine, view, q: text, category, city, urgency, matching, sort } = req.query;
  const me = req.user._id;
  const q = {};

  if (req.user.role === 'client') {
    q.client = me;
    if (status) q.status = status;
  } else if (req.user.role === 'technician') {
    if (mine === '1') {
      q.assignedTechnician = me;
      if (status) q.status = status;
    } else if (view === 'requests') {
      Object.assign(q, { requestedTechnician: me, status: 'pending', requestDeclined: false });
    } else if (view === 'bids') {
      q['bids.technician'] = me;
      if (status) q.status = status;
    } else {
      // Open marketplace.
      Object.assign(q, { status: 'pending', requestedTechnician: null });
      if (matching === '1' && req.user.skills.length) q.category = { $in: req.user.skills };
    }
  } else if (req.user.role === 'admin') {
    if (status) q.status = status;
  } else {
    return res.json([]);
  }

  if (category) q.category = String(category);
  if (urgency && URGENCY_LEVELS.includes(urgency)) q.urgency = urgency;
  if (city) q.city = new RegExp(`^${escapeRegex(String(city).trim())}$`, 'i');
  if (text) {
    const rx = new RegExp(escapeRegex(String(text).trim()), 'i');
    q.$or = [{ title: rx }, { description: rx }, { location: rx }];
  }

  const sorts = { newest: { createdAt: -1 }, oldest: { createdAt: 1 }, budget: { budget: -1, createdAt: -1 } };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const [jobs, total] = await Promise.all([
    populateJob(Job.find(q)).sort(sorts[sort] || sorts.newest).skip(skip).limit(limit),
    Job.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(jobs.map((j) => redactContacts(j.toJSON(), req.user)));
});

// ---------------------------------------------------------------- create

router.post(
  '/',
  authRequired,
  requireRole('client'),
  upload.array('images', 5),
  [
    body('title').trim().isLength({ min: 3, max: 120 }).withMessage('Title must be 3–120 characters'),
    body('description').trim().isLength({ min: 10, max: 3000 }).withMessage('Describe the problem in at least 10 characters'),
    body('category').optional({ values: 'falsy' }).isIn(serviceCategoryKeys).withMessage('Unknown category'),
    body('budget').optional({ values: 'falsy' }).isFloat({ min: 0, max: 10000000 }).withMessage('Budget must be a positive number').toFloat(),
    body('location').optional().trim().isLength({ max: 200 }),
    body('city').optional().trim().isLength({ max: 60 }),
    body('urgency').optional({ values: 'falsy' }).isIn(URGENCY_LEVELS).withMessage('Unknown urgency'),
    body('preferredDate')
      .optional({ values: 'falsy' })
      .isISO8601()
      .withMessage('Invalid preferred date')
      .custom((v) => new Date(v).getTime() >= Date.now() - 24 * 3600 * 1000)
      .withMessage('Preferred date cannot be in the past'),
    body('requestedTechnician').optional({ values: 'falsy' }).isMongoId().withMessage('Invalid technician')
  ],
  validate,
  async (req, res) => {
    const { title, description, category, budget, location, city, urgency, preferredDate, requestedTechnician } = req.body;

    let target = null;
    if (requestedTechnician) {
      target = await User.findOne({ _id: requestedTechnician, role: 'technician', status: { $ne: 'suspended' } });
      if (!target) throw badRequest('That technician is not available');
    }

    const job = new Job({
      client: req.user._id,
      title,
      description,
      category: category || 'general',
      budget: Number(budget) || 0,
      location: location || '',
      city: city || req.user.city || '',
      urgency: urgency || 'normal',
      preferredDate: preferredDate ? new Date(preferredDate) : null,
      images: (req.files || []).map((f) => f.filename),
      requestedTechnician: target ? target._id : null
    });
    job.log('pending', req.user._id, target ? `Service requested from ${target.name}` : 'Job posted');
    await job.save();

    if (target) {
      await notify(target._id, 'request', 'New service request', `${req.user.name} requested you for "${job.title}"`, {
        jobId: job._id
      });
      realtime.emit(target._id, 'job:request', { jobId: job._id, title: job.title, clientName: req.user.name });
    } else {
      // Let every connected technician know there's fresh work to bid on.
      realtime.emitRole('technician', 'job:new', {
        jobId: job._id,
        title: job.title,
        category: job.category,
        budget: job.budget,
        city: job.city,
        urgency: job.urgency
      });
    }
    res.status(201).json(job);
  }
);

// ---------------------------------------------------------------- detail

router.get('/:id', authRequired, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Job not found');
  const job = await populateJob(Job.findById(req.params.id)).populate('history.by', 'name role');
  if (!job) throw notFound('Job not found');
  if (!canView(job, req.user)) throw forbidden('You do not have access to this job');
  res.json(redactContacts(job.toJSON(), req.user));
});

// ------------------------------------------------------------------ bids

router.post(
  '/:id/bids',
  authRequired,
  requireRole('technician'),
  [
    body('amount').isFloat({ gt: 0, max: 10000000 }).withMessage('Bid amount must be greater than 0').toFloat(),
    body('etaDays').optional().isInt({ min: 0, max: 365 }).withMessage('ETA must be 0–365 days').toInt(),
    body('message').optional().isString().isLength({ max: 500 }).withMessage('Message is too long (max 500 characters)')
  ],
  validate,
  async (req, res) => {
    const job = await loadJob(req.params.id);
    if (job.status !== 'pending') throw badRequest('This job is no longer accepting bids');
    if (job.requestedTechnician && !sameId(job.requestedTechnician, req.user._id)) {
      throw forbidden('This is a private request for another technician');
    }
    if (job.bids.some((b) => sameId(b.technician, req.user._id))) throw conflict('You already placed a bid on this job');

    const { amount, message, etaDays } = req.body;
    job.bids.push({ technician: req.user._id, amount, message: message || '', etaDays: etaDays ?? 1 });
    job.log('bid', req.user._id, `${req.user.name} quoted ${amount}`);
    await job.save();

    // Responsiveness for the AI ranker: minutes from posting to first bid.
    req.user.recordResponse((Date.now() - job.createdAt.getTime()) / 60000);
    await req.user.save();

    await notify(job.client, 'bid', 'New quote on your job', `${req.user.name} quoted ${amount} for "${job.title}"`, {
      jobId: job._id
    });
    realtime.emit(job.client, 'job:bid', { jobId: job._id, title: job.title, technicianName: req.user.name, amount });
    res.status(201).json(job);
  }
);

// Withdraw my own bid (technician). Only while the job is still pending.
router.delete('/:id/bids/me', authRequired, requireRole('technician'), async (req, res) => {
  const job = await loadJob(req.params.id);
  const bid = job.bids.find((b) => sameId(b.technician, req.user._id));
  if (!bid) throw notFound('No bid to cancel');
  if (bid.status !== 'pending' || job.status !== 'pending') throw badRequest('Only pending bids can be withdrawn');
  job.bids.id(bid._id).deleteOne();
  job.log('bid_withdrawn', req.user._id, `${req.user.name} withdrew their quote`);
  await job.save();
  await notify(job.client, 'bid', 'Quote withdrawn', `${req.user.name} withdrew their quote`, { jobId: job._id });
  realtime.emit(job.client, 'job:bid', { jobId: job._id, title: job.title, technicianName: req.user.name, cancelled: true });
  res.json({ ok: true });
});

// The requested technician turns down a direct service request.
router.post('/:id/decline', authRequired, requireRole('technician'), async (req, res) => {
  const job = await loadJob(req.params.id);
  if (!sameId(job.requestedTechnician, req.user._id)) throw forbidden('This request was not sent to you');
  if (job.status !== 'pending') throw badRequest('This job is no longer pending');
  job.requestDeclined = true;
  const reason = String(req.body?.reason || '').slice(0, 300);
  job.log('request_declined', req.user._id, reason || `${req.user.name} declined the request`);
  await job.save();
  await notify(
    job.client,
    'request',
    'Request declined',
    `${req.user.name} can't take "${job.title}". You can open it to all technicians.`,
    { jobId: job._id }
  );
  realtime.emit(job.client, 'job:status', { jobId: job._id, title: job.title, status: 'request_declined' });
  res.json(job);
});

// Client turns a direct request into an open job every technician can bid on.
router.post('/:id/open', authRequired, requireRole('client'), async (req, res) => {
  const job = await loadJob(req.params.id);
  if (!sameId(job.client, req.user._id)) throw forbidden('Not your job');
  if (job.status !== 'pending') throw badRequest('Only pending jobs can be opened');
  if (!job.requestedTechnician) return res.json(job);
  job.requestedTechnician = null;
  job.requestDeclined = false;
  job.log('opened', req.user._id, 'Opened to all technicians');
  await job.save();
  realtime.emitRole('technician', 'job:new', {
    jobId: job._id,
    title: job.title,
    category: job.category,
    budget: job.budget,
    city: job.city,
    urgency: job.urgency
  });
  res.json(job);
});

router.post('/:id/accept/:bidId', authRequired, requireRole('client'), async (req, res) => {
  const job = await loadJob(req.params.id);
  if (!sameId(job.client, req.user._id)) throw forbidden('Not your job');
  if (job.status !== 'pending') throw badRequest('A technician has already been hired for this job');
  const bid = mongoose.isValidObjectId(req.params.bidId) ? job.bids.id(req.params.bidId) : null;
  if (!bid) throw notFound('Bid not found');
  if (bid.status !== 'pending') throw badRequest('This bid is no longer available');

  bid.status = 'accepted';
  const rejected = [];
  job.bids.forEach((b) => {
    if (!sameId(b._id, bid._id)) {
      b.status = 'rejected';
      rejected.push(b.technician);
    }
  });
  job.acceptedBid = bid._id;
  job.assignedTechnician = bid.technician;
  job.agreedPrice = bid.amount;
  job.status = 'in_progress';
  const tech = await User.findById(bid.technician);
  job.log('in_progress', req.user._id, `Hired ${tech ? tech.name : 'technician'} for ${bid.amount}`);
  await job.save();

  await User.updateOne({ _id: bid.technician }, { $inc: { jobsAssigned: 1 } });
  await notify(bid.technician, 'job_status', 'You got the job!', `You were hired for "${job.title}"`, { jobId: job._id });
  realtime.emit(bid.technician, 'job:hired', { jobId: job._id, title: job.title, amount: bid.amount });
  for (const techId of rejected) {
    await notify(techId, 'job_status', 'Job filled', `"${job.title}" was assigned to another technician`, { jobId: job._id });
    realtime.emit(techId, 'job:status', { jobId: job._id, title: job.title, status: 'filled' });
  }
  res.json(job);
});

// ---------------------------------------------------------------- status

router.patch(
  '/:id/status',
  authRequired,
  [
    body('status').isIn(Job.STATUSES).withMessage('Invalid status'),
    body('note').optional().isString().isLength({ max: 500 })
  ],
  validate,
  async (req, res) => {
    const { status, note } = req.body;
    const job = await loadJob(req.params.id);
    const isClient = sameId(job.client, req.user._id);
    const isTech = sameId(job.assignedTechnician, req.user._id);
    const isAdmin = req.user.role === 'admin';
    if (!isClient && !isTech && !isAdmin) throw forbidden('Not allowed');

    const allowedRoles = TRANSITIONS[job.status]?.[status];
    if (!allowedRoles) throw badRequest(`Cannot change a ${job.status.replace('_', ' ')} job to ${status.replace('_', ' ')}`);
    const actorRole = isClient ? 'client' : isTech ? 'technician' : null;
    if (!isAdmin && !allowedRoles.includes(actorRole)) {
      throw forbidden(`Only the ${allowedRoles.join(' or ')} can mark this job ${status.replace('_', ' ')}`);
    }

    job.status = status;
    if (status === 'completed') {
      job.completedAt = new Date();
      if (job.assignedTechnician) {
        await User.updateOne({ _id: job.assignedTechnician }, { $inc: { jobsCompleted: 1 } });
      }
    } else if (status === 'cancelled') {
      job.cancelledAt = new Date();
      job.cancelReason = note || '';
    }
    job.log(status, req.user._id, note || '');
    await job.save();

    const others = [job.client, job.assignedTechnician, job.requestedTechnician].filter(
      (u) => u && !sameId(u, req.user._id)
    );
    const label = status === 'completed' ? 'completed' : status.replace('_', ' ');
    for (const u of others) {
      await notify(u, 'job_status', `Job ${label}`, job.title + (note ? ` — ${note}` : ''), { jobId: job._id });
      realtime.emit(u, 'job:status', { jobId: job._id, title: job.title, status });
    }
    res.json(job);
  }
);

router.post(
  '/:id/rate',
  authRequired,
  requireRole('client'),
  [
    body('rating').isInt({ min: 1, max: 5 }).withMessage('Rating must be 1–5 stars').toInt(),
    body('review').optional().isString().isLength({ max: 1000 }).withMessage('Review is too long (max 1000 characters)')
  ],
  validate,
  async (req, res) => {
    const { rating, review } = req.body;
    const job = await loadJob(req.params.id);
    if (!sameId(job.client, req.user._id)) throw forbidden('Not your job');
    if (job.status !== 'completed') throw badRequest('You can rate a job once it is completed');
    if (job.rating) throw conflict('You already rated this job');

    job.rating = rating;
    job.review = (review || '').trim();
    job.log('rated', req.user._id, `${rating}★`);
    await job.save();

    const tech = await User.findById(job.assignedTechnician);
    if (tech) {
      const total = tech.rating * tech.ratingCount + rating;
      tech.ratingCount += 1;
      tech.rating = Math.round((total / tech.ratingCount) * 100) / 100;
      await tech.save();
      await notify(tech._id, 'review', `New ${rating}★ review`, job.review || job.title, { jobId: job._id });
      realtime.emit(tech._id, 'job:rated', { jobId: job._id, title: job.title, rating, review: job.review });
    }
    res.json(job);
  }
);

// AI-ranked bids — the job's bids sorted by technician match score, with
// human-readable reasons for each ranking.
router.get('/:id/ranked-bids', authRequired, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Job not found');
  const job = await Job.findById(req.params.id).populate('bids.technician', BIDDER_FIELDS);
  if (!job) throw notFound('Job not found');
  if (!sameId(job.client, req.user._id) && req.user.role !== 'admin') throw forbidden('Only the job owner can see ranked bids');

  const techs = job.bids
    .filter((b) => b.technician)
    .map((b) => {
      const t = b.technician;
      return {
        bidId: String(b._id),
        technicianId: String(t._id),
        name: t.name,
        avatar: t.avatar,
        amount: b.amount,
        etaDays: b.etaDays,
        message: b.message,
        bidStatus: b.status,
        createdAt: b.createdAt,
        rating: t.rating || 0,
        ratingCount: t.ratingCount || 0,
        jobsCompleted: t.jobsCompleted || 0,
        jobsAssigned: t.jobsAssigned || 0,
        completionRate: t.jobsAssigned ? Math.min(1, t.jobsCompleted / t.jobsAssigned) : 0,
        avgResponseMinutes: t.avgResponseMinutes || 60,
        responseSpeed: 1 / (1 + (t.avgResponseMinutes || 60) / 60),
        skills: t.skills || [],
        headline: t.headline || '',
        bio: t.bio || '',
        city: t.city || '',
        kycStatus: t.kycStatus,
        experienceYears: t.experienceYears || 0,
        isAvailable: t.isAvailable !== false,
        online: realtime.isOnline(t._id)
      };
    });

  const ranked = await rankTechnicians(techs, {
    jobCategory: job.category || '',
    description: `${job.title}. ${job.description}`,
    budget: job.budget,
    city: job.city,
    urgency: job.urgency
  });
  res.json(ranked);
});

module.exports = router;
