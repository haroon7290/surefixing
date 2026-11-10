const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Job = require('../models/Job');
const User = require('../models/User');
const { authRequired, requireRole } = require('../middleware/auth');
const { validate, discardUploads } = require('../middleware/validate');
const upload = require('../middleware/upload');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { rankTechnicians } = require('../utils/ai');
const jobs = require('../services/jobs');
const { URGENCY_LEVELS, PAYMENT_METHODS, serviceCategoryKeys } = require('../config/catalog');
const { escapeRegex, paginate, setTotal, sameId, badRequest, forbidden, notFound, conflict } = require('../utils/http');

const router = express.Router();

const USER_CARD = 'name avatar rating ratingCount city kycStatus';
const CONTACT = 'phone email';
const BIDDER_FIELDS =
  'name avatar rating ratingCount jobsCompleted jobsAssigned avgResponseMinutes skills headline bio city kycStatus experienceYears hourlyRate isAvailable';

async function loadJob(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Job not found');
  const job = await Job.findById(id);
  if (!job) throw notFound('Job not found');
  return job;
}

function canView(job, user) {
  if (user.role === 'admin' || sameId(job.client, user._id)) return true;
  if (user.role !== 'technician') return false;
  return (
    jobs.isOpenMarketJob(job) ||
    sameId(job.requestedTechnician, user._id) ||
    sameId(job.assignedTechnician, user._id) ||
    job.bids.some((b) => sameId(b.technician, user._id))
  );
}

// What the app receives. Phone and email are only shared between the client
// and the hired technician (and admins); a technician browsing the market
// sees how many quotes a job has, not the other technicians' prices.
function present(job, user) {
  const json = job.toJSON();
  const isClient = sameId(json.client, user._id);
  const isAssigned = sameId(json.assignedTechnician, user._id);
  const hired = json.assignedTechnician && ['in_progress', 'completed'].includes(json.status);
  const showContacts = user.role === 'admin' || (hired && (isClient || isAssigned));
  if (!showContacts) {
    for (const key of ['client', 'assignedTechnician', 'requestedTechnician']) {
      if (json[key] && typeof json[key] === 'object') {
        delete json[key].phone;
        delete json[key].email;
      }
    }
  }
  json.bidCount = json.bids.filter((b) => b.status !== 'withdrawn').length;
  if (!isClient && user.role !== 'admin') json.bids = json.bids.filter((b) => sameId(b.technician, user._id));
  if (!isClient && !isAssigned && user.role !== 'admin') delete json.payment;
  json.autoCompleteAt = jobs.autoCompleteAt(job);
  return json;
}

function populateJob(query) {
  return query
    .populate('client', `${USER_CARD} ${CONTACT}`)
    .populate('assignedTechnician', `${USER_CARD} ${CONTACT}`)
    .populate('requestedTechnician', USER_CARD)
    .populate('bids.technician', BIDDER_FIELDS);
}

async function respond(res, job, user, status = 200) {
  const fresh = await populateJob(Job.findById(job._id)).populate('history.by', 'name role');
  res.status(status).json(present(fresh, user));
}

// ------------------------------------------------------------------ list

// Client: their own jobs. Admin: all. Technician:
//   (default)       the open marketplace  ?q= ?category= ?city= ?urgency= ?matching=1
//   ?view=requests  direct requests waiting for their answer
//   ?view=bids      jobs they quoted on
//   ?mine=1         jobs they were hired for
router.get('/', authRequired, async (req, res) => {
  const { status, mine, view, q: text, category, city, urgency, matching, sort } = req.query;
  const me = req.user._id;
  const q = {};

  if (req.user.role === 'client') {
    q.client = me;
    if (status) q.status = { $in: String(status).split(',') };
  } else if (req.user.role === 'technician') {
    if (mine === '1') {
      q.assignedTechnician = me;
      if (status) q.status = { $in: String(status).split(',') };
    } else if (view === 'requests') {
      Object.assign(q, { requestedTechnician: me, status: 'pending', requestDeclined: false });
    } else if (view === 'bids') {
      Object.assign(q, { status: 'pending', bids: { $elemMatch: { technician: me, status: 'pending' } } });
    } else {
      Object.assign(q, { status: 'pending', requestedTechnician: null });
      if (matching === '1' && req.user.skills.length) q.category = { $in: req.user.skills };
    }
  } else if (req.user.role === 'admin') {
    if (status) q.status = { $in: String(status).split(',') };
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
  const [items, total] = await Promise.all([
    populateJob(Job.find(q)).sort(sorts[sort] || sorts.newest).skip(skip).limit(limit),
    Job.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(items.map((j) => present(j, req.user)));
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
      if (!target) {
        discardUploads(req);
        throw badRequest('That technician is not available');
      }
    }

    const job = new Job({
      client: req.user._id,
      title,
      description,
      category: category || 'general',
      budget: Number(budget) || 0,
      location: location || req.user.address || '',
      city: city || req.user.city || '',
      urgency: urgency || 'normal',
      preferredDate: preferredDate ? new Date(preferredDate) : null,
      images: (req.files || []).map((f) => f.filename),
      requestedTechnician: target ? target._id : null
    });
    job.log('posted', req.user._id, target ? `Service requested from ${target.name}` : 'Job posted');
    await job.save();

    if (target) {
      await notify(target._id, 'request', 'New service request', `${req.user.name} requested you for "${job.title}"`, { jobId: job._id });
      realtime.emit(target._id, 'job:request', { jobId: job._id, title: job.title, clientName: req.user.name });
    } else {
      jobs.announce(job);
    }
    await respond(res, job, req.user, 201);
  }
);

// ---------------------------------------------------------------- detail

router.get('/:id', authRequired, async (req, res) => {
  const job = await loadJob(req.params.id);
  if (!canView(job, req.user)) throw forbidden('You do not have access to this job');
  await respond(res, job, req.user);
});

// AI-ranked quotes: the job's quotes sorted by technician match score, each
// with human-readable reasons.
router.get('/:id/ranked-bids', authRequired, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Job not found');
  const job = await Job.findById(req.params.id).populate('bids.technician', BIDDER_FIELDS);
  if (!job) throw notFound('Job not found');
  if (!sameId(job.client, req.user._id) && req.user.role !== 'admin') throw forbidden('Only the job owner can see ranked quotes');

  const candidates = job.bids
    .filter((b) => b.technician && b.status !== 'withdrawn')
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
        avgResponseMinutes: t.avgResponseMinutes || 60,
        skills: t.skills || [],
        headline: t.headline || '',
        bio: t.bio || '',
        city: t.city || '',
        kycStatus: t.kycStatus,
        experienceYears: t.experienceYears || 0,
        hourlyRate: t.hourlyRate || 0,
        isAvailable: t.isAvailable !== false,
        online: realtime.isOnline(t._id)
      };
    });

  const ranked = await rankTechnicians(candidates, {
    jobCategory: job.category || '',
    description: `${job.title}. ${job.description}`,
    budget: job.budget,
    city: job.city,
    urgency: job.urgency
  });
  res.json(ranked);
});

// ---------------------------------------------------------------- quotes

router.post(
  '/:id/bids',
  authRequired,
  requireRole('technician'),
  [
    body('amount').isFloat({ gt: 0, max: 10000000 }).withMessage('Your quote must be greater than 0').toFloat(),
    body('etaDays').optional().isInt({ min: 0, max: 365 }).withMessage('ETA must be 0–365 days').toInt(),
    body('message').optional().isString().isLength({ max: 500 }).withMessage('Message is too long (max 500 characters)')
  ],
  validate,
  async (req, res) => {
    const job = await loadJob(req.params.id);
    if (job.status !== 'pending') throw badRequest('This job is no longer accepting quotes');
    if (job.requestedTechnician && !sameId(job.requestedTechnician, req.user._id)) {
      throw forbidden('This is a private request for another technician');
    }
    const mine = job.bids.find((b) => sameId(b.technician, req.user._id));
    if (mine) throw conflict(mine.status === 'withdrawn' ? 'You withdrew from this job' : 'You already quoted on this job');

    const { amount, message, etaDays } = req.body;
    job.bids.push({ technician: req.user._id, amount, message: message || '', etaDays: etaDays ?? 1 });
    job.log('bid', req.user._id, `${req.user.name} quoted ${amount}`);
    await job.save();

    // Responsiveness for the AI ranker: minutes from posting to first quote.
    req.user.recordResponse((Date.now() - job.createdAt.getTime()) / 60000);
    await req.user.save();

    await notify(job.client, 'bid', 'New quote on your job', `${req.user.name} quoted ${amount} for "${job.title}"`, { jobId: job._id });
    realtime.emit(job.client, 'job:bid', { jobId: job._id, title: job.title, technicianName: req.user.name, amount });
    await respond(res, job, req.user, 201);
  }
);

// Take back my own quote while the job is still open.
router.delete('/:id/bids/me', authRequired, requireRole('technician'), async (req, res) => {
  const job = await loadJob(req.params.id);
  const bid = job.bids.find((b) => sameId(b.technician, req.user._id));
  if (!bid) throw notFound('You have no quote on this job');
  if (bid.status !== 'pending' || job.status !== 'pending') throw badRequest('Only pending quotes can be withdrawn');
  job.bids.id(bid._id).deleteOne();
  job.log('bid_withdrawn', req.user._id, `${req.user.name} withdrew their quote`);
  await job.save();
  await notify(job.client, 'bid', 'Quote withdrawn', `${req.user.name} withdrew their quote on "${job.title}"`, { jobId: job._id });
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
  await notify(job.client, 'request', 'Request declined', `${req.user.name} can't take "${job.title}". You can open it to all technicians.`, {
    jobId: job._id
  });
  realtime.emit(job.client, 'job:status', { jobId: job._id, title: job.title, status: 'request_declined' });
  await respond(res, job, req.user);
});

// The client turns a direct request into an open job everyone can quote on.
router.post('/:id/open', authRequired, requireRole('client'), async (req, res) => {
  const job = await loadJob(req.params.id);
  if (!sameId(job.client, req.user._id)) throw forbidden('Not your job');
  if (job.status !== 'pending') throw badRequest('Only pending jobs can be opened');
  if (job.requestedTechnician) {
    job.requestedTechnician = null;
    job.requestDeclined = false;
    job.log('opened', req.user._id, 'Opened to all technicians');
    await job.save();
    jobs.announce(job);
  }
  await respond(res, job, req.user);
});

// ------------------------------------------------------------- lifecycle

// Hire the technician behind a quote. Body: { paymentMethod: wallet | cash }.
router.post(
  '/:id/accept/:bidId',
  authRequired,
  requireRole('client'),
  [body('paymentMethod').optional().isIn(PAYMENT_METHODS).withMessage('Choose wallet or cash')],
  validate,
  async (req, res) => {
    const job = await loadJob(req.params.id);
    if (!sameId(job.client, req.user._id)) throw forbidden('Not your job');
    if (job.status !== 'pending') throw badRequest('A technician has already been hired for this job');
    const bid = mongoose.isValidObjectId(req.params.bidId) ? job.bids.id(req.params.bidId) : null;
    if (!bid) throw notFound('Quote not found');
    if (bid.status !== 'pending') throw badRequest('This quote is no longer available');
    await jobs.hire(job, bid, req.user, req.body.paymentMethod || 'cash');
    await respond(res, job, req.user);
  }
);

function assertAssigned(job, user) {
  if (!sameId(job.assignedTechnician, user._id)) throw forbidden('Only the hired technician can do this');
}

// Technician progress: { stage: on_the_way | working }.
router.patch(
  '/:id/stage',
  authRequired,
  requireRole('technician'),
  [body('stage').isIn(['on_the_way', 'working']).withMessage('Unknown stage')],
  validate,
  async (req, res) => {
    const job = await loadJob(req.params.id);
    assertAssigned(job, req.user);
    await jobs.advance(job, req.user, req.body.stage);
    await respond(res, job, req.user);
  }
);

// Technician: the work is finished. Optional note and up to 4 photos as proof.
router.post(
  '/:id/done',
  authRequired,
  requireRole('technician'),
  upload.array('images', 4),
  [body('note').optional().isString().isLength({ max: 500 }).withMessage('Note is too long (max 500 characters)')],
  validate,
  async (req, res) => {
    try {
      const job = await loadJob(req.params.id);
      assertAssigned(job, req.user);
      await jobs.advance(job, req.user, 'done', {
        note: String(req.body.note || '').trim(),
        images: (req.files || []).map((f) => f.filename)
      });
      await respond(res, job, req.user);
    } catch (err) {
      discardUploads(req);
      throw err;
    }
  }
);

// Confirm the job is complete: releases the payment to the technician. The
// client can confirm at any time; the technician only once the client has
// had AUTO_CONFIRM_HOURS to respond after "done".
router.post('/:id/complete', authRequired, async (req, res) => {
  const job = await loadJob(req.params.id);
  const isClient = sameId(job.client, req.user._id);
  const isTech = sameId(job.assignedTechnician, req.user._id);
  if (!isClient && !isTech && req.user.role !== 'admin') throw forbidden('Not your job');
  if (isTech) {
    const at = jobs.autoCompleteAt(job);
    if (!at) throw badRequest('Mark the work as finished first, then the client confirms it');
    if (at.getTime() > Date.now()) throw badRequest('Waiting for the client to confirm. You can close the job yourself if they have not answered in time.');
  }
  await jobs.complete(job, req.user, String(req.body?.note || '').slice(0, 500));
  await respond(res, job, req.user);
});

// Client cancels: any time before a technician is hired, and after hiring
// until the work has started. Body: { reason }.
router.post('/:id/cancel', authRequired, [body('reason').optional().isString().isLength({ max: 500 })], validate, async (req, res) => {
  const job = await loadJob(req.params.id);
  const isAdmin = req.user.role === 'admin';
  if (!sameId(job.client, req.user._id) && !isAdmin) throw forbidden('Only the client can cancel this job');
  if (!isAdmin && job.status === 'in_progress' && !jobs.BEFORE_WORK.includes(job.stage)) {
    throw badRequest('Work has already started. If something is wrong, report a problem and our team will step in.');
  }
  await jobs.cancel(job, req.user, String(req.body.reason || '').trim());
  await respond(res, job, req.user);
});

// The hired technician backs out before starting; the job reopens for quotes.
router.post(
  '/:id/withdraw',
  authRequired,
  requireRole('technician'),
  [body('reason').optional().isString().isLength({ max: 500 })],
  validate,
  async (req, res) => {
    const job = await loadJob(req.params.id);
    assertAssigned(job, req.user);
    await jobs.withdraw(job, req.user, String(req.body.reason || '').trim());
    if (jobs.isOpenMarketJob(job)) jobs.announce(job);
    res.json({ ok: true });
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
    await respond(res, job, req.user);
  }
);

module.exports = router;
