// Job-scoped chat. A thread is (job, client, technician): the client can
// talk to any technician who quoted on, was requested for, or is assigned
// to the job — so questions can be asked before hiring.
const express = require('express');
const mongoose = require('mongoose');
const Message = require('../models/Message');
const Job = require('../models/Job');
const User = require('../models/User');
const { authRequired } = require('../middleware/auth');
const upload = require('../middleware/upload');
const { discardUploads } = require('../middleware/validate');
const realtime = require('../utils/realtime');
const { badRequest, forbidden, notFound, sameId } = require('../utils/http');

const router = express.Router();

function technicianIds(job) {
  return new Set(
    [job.assignedTechnician, job.requestedTechnician, ...job.bids.map((b) => b.technician)]
      .filter(Boolean)
      .map((id) => String(id))
  );
}

// Returns the other participant's id for this user on this job.
function counterpart(job, user, withId) {
  const me = String(user._id);
  const techs = technicianIds(job);
  if (sameId(job.client, me)) {
    const other = withId || job.assignedTechnician || job.requestedTechnician;
    if (!other) throw badRequest('Choose a technician to message');
    if (!techs.has(String(other))) throw forbidden('You can only message technicians on this job');
    return String(other);
  }
  if (techs.has(me)) return String(job.client);
  throw forbidden('Not a participant');
}

function threadFilter(jobId, a, b) {
  return {
    job: jobId,
    $or: [
      { sender: a, recipient: b },
      { sender: b, recipient: a }
    ]
  };
}

function messagePayload(msg) {
  return {
    _id: msg._id,
    job: msg.job,
    sender: msg.sender,
    recipient: msg.recipient,
    text: msg.text,
    image: msg.image,
    readAt: msg.readAt,
    createdAt: msg.createdAt
  };
}

async function loadJob(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Job not found');
  const job = await Job.findById(id);
  if (!job) throw notFound('Job not found');
  return job;
}

async function markRead(jobId, me, other) {
  const r = await Message.updateMany(
    { job: jobId, sender: other, recipient: me, readAt: null },
    { $set: { readAt: new Date() } }
  );
  if (r.modifiedCount) realtime.emit(other, 'message:read', { jobId: String(jobId), by: String(me) });
}

// Inbox: one row per conversation with last message + unread count.
router.get('/', authRequired, async (req, res) => {
  const me = req.user._id;
  const rows = await Message.aggregate([
    { $match: { $or: [{ sender: me }, { recipient: me }] } },
    { $sort: { createdAt: -1 } },
    { $addFields: { other: { $cond: [{ $eq: ['$sender', me] }, '$recipient', '$sender'] } } },
    {
      $group: {
        _id: { job: '$job', other: '$other' },
        last: { $first: '$$ROOT' },
        unread: {
          $sum: { $cond: [{ $and: [{ $eq: ['$recipient', me] }, { $not: ['$readAt'] }] }, 1, 0] }
        }
      }
    },
    { $sort: { 'last.createdAt': -1 } },
    { $limit: 200 }
  ]);

  const jobIds = [...new Set(rows.map((r) => String(r._id.job)))];
  const userIds = [...new Set(rows.map((r) => String(r._id.other)))];
  const [jobs, users] = await Promise.all([
    Job.find({ _id: { $in: jobIds } }).select('title status category'),
    User.find({ _id: { $in: userIds } }).select('name avatar role')
  ]);
  const jobMap = new Map(jobs.map((j) => [String(j._id), j]));
  const userMap = new Map(users.map((u) => [String(u._id), u]));

  res.json(
    rows
      .filter((r) => jobMap.has(String(r._id.job)) && userMap.has(String(r._id.other)))
      .map((r) => {
        const job = jobMap.get(String(r._id.job));
        const other = userMap.get(String(r._id.other));
        return {
          jobId: job._id,
          jobTitle: job.title,
          jobStatus: job.status,
          jobCategory: job.category,
          other: { id: other._id, name: other.name, avatar: other.avatar, role: other.role, online: realtime.isOnline(other._id) },
          lastMessage: messagePayload(r.last),
          unread: r.unread
        };
      })
  );
});

router.get('/unread-count', authRequired, async (req, res) => {
  const count = await Message.countDocuments({ recipient: req.user._id, readAt: null });
  res.json({ count });
});

// Thread history. Clients pass ?with=<technicianId> when the job has more
// than one technician they're talking to. Reading marks messages as read.
router.get('/:jobId', authRequired, async (req, res) => {
  const job = await loadJob(req.params.jobId);
  if (req.user.role === 'admin' && !req.query.with) {
    const all = await Message.find({ job: job._id }).sort({ createdAt: 1 });
    return res.json(all.map(messagePayload));
  }
  const other = counterpart(job, req.user, req.query.with);
  const msgs = await Message.find(threadFilter(job._id, req.user._id, other)).sort({ createdAt: 1 }).limit(500);
  await markRead(job._id, req.user._id, other);
  res.json(msgs.map(messagePayload));
});

router.post('/:jobId/read', authRequired, async (req, res) => {
  const job = await loadJob(req.params.jobId);
  const other = counterpart(job, req.user, req.query.with || req.body?.with);
  await markRead(job._id, req.user._id, other);
  res.json({ ok: true });
});

// Send a message: JSON {text, to?} or multipart with an "image" file.
router.post('/:jobId', authRequired, upload.single('image'), async (req, res) => {
  try {
    const job = await loadJob(req.params.jobId);
    const other = counterpart(job, req.user, req.body.to || req.query.with);
    const isTech = !sameId(job.client, req.user._id);
    if (isTech && job.assignedTechnician && !sameId(job.assignedTechnician, req.user._id)) {
      throw forbidden('This job was assigned to another technician');
    }
    if (job.status === 'cancelled') throw badRequest('This job was cancelled');

    const text = String(req.body.text || '').trim();
    if (!text && !req.file) throw badRequest('Message cannot be empty');
    if (text.length > 2000) throw badRequest('Message is too long (max 2000 characters)');

    const msg = await Message.create({
      job: job._id,
      sender: req.user._id,
      recipient: other,
      text,
      image: req.file ? req.file.filename : ''
    });
    // Both ends get the message so every open device updates; the
    // recipient's app also shows an in-app toast when not in this chat.
    const payload = { ...messagePayload(msg), senderName: req.user.name, jobTitle: job.title };
    realtime.emit(other, 'message:new', payload);
    realtime.emit(req.user._id, 'message:new', payload);
    res.status(201).json(messagePayload(msg));
  } catch (err) {
    discardUploads(req);
    throw err;
  }
});

module.exports = router;
