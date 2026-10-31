// Chat. Two kinds of thread:
//   job:  (job, client, technician) — the client can talk to any technician
//         who quoted on, was requested for, or is assigned to the job, so
//         questions can be asked before hiring;
//   tool: (tool, customer, supplier) — ask about a tool before renting or
//         buying it, then arrange pickup, delivery and return.
const express = require('express');
const mongoose = require('mongoose');
const Message = require('../models/Message');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
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

function threadFilter(scope, a, b) {
  return {
    ...scope,
    $or: [
      { sender: a, recipient: b },
      { sender: b, recipient: a }
    ]
  };
}

function messagePayload(msg) {
  return {
    _id: msg._id,
    job: msg.job || null,
    tool: msg.tool || null,
    // Stable thread key the app uses to match realtime events to an open chat.
    thread: msg.tool ? `tool:${msg.tool}` : String(msg.job),
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

async function markRead(scope, me, other) {
  const r = await Message.updateMany({ ...scope, sender: other, recipient: me, readAt: null }, { $set: { readAt: new Date() } });
  if (!r.modifiedCount) return;
  const thread = scope.tool ? `tool:${scope.tool}` : String(scope.job);
  realtime.emit(other, 'message:read', { jobId: scope.job ? String(scope.job) : '', thread, by: String(me) });
}

async function loadTool(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Tool not found');
  const tool = await Tool.findById(id).select('name supplier category images image');
  if (!tool) throw notFound('Tool not found');
  return tool;
}

// Tool threads: a customer always talks to the tool's supplier; the supplier
// can talk to anyone who has rented/requested the tool or already wrote to
// them about it (they choose who with ?with= / "to").
async function toolCounterpart(tool, user, withId) {
  const me = String(user._id);
  const supplier = String(tool.supplier);
  if (me !== supplier) return supplier;
  if (!withId || !mongoose.isValidObjectId(withId)) throw badRequest('Choose a customer to message');
  if (String(withId) === me) throw badRequest("You can't message yourself");
  const known =
    (await Rental.exists({ tool: tool._id, renter: withId })) ||
    (await Message.exists({ tool: tool._id, sender: withId, recipient: me }));
  if (!known) throw forbidden('You can only message customers who asked about or rented this tool');
  return String(withId);
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
        _id: { job: '$job', tool: '$tool', other: '$other' },
        last: { $first: '$$ROOT' },
        unread: {
          $sum: { $cond: [{ $and: [{ $eq: ['$recipient', me] }, { $not: ['$readAt'] }] }, 1, 0] }
        }
      }
    },
    { $sort: { 'last.createdAt': -1 } },
    { $limit: 200 }
  ]);

  const ids = (key) => [...new Set(rows.map((r) => r._id[key]).filter(Boolean).map(String))];
  const [jobs, tools, users] = await Promise.all([
    Job.find({ _id: { $in: ids('job') } }).select('title status category'),
    Tool.find({ _id: { $in: ids('tool') } }).select('name category images image'),
    User.find({ _id: { $in: ids('other') } }).select('name avatar role')
  ]);
  const jobMap = new Map(jobs.map((j) => [String(j._id), j]));
  const toolMap = new Map(tools.map((t) => [String(t._id), t]));
  const userMap = new Map(users.map((u) => [String(u._id), u]));

  const out = [];
  for (const r of rows) {
    const other = userMap.get(String(r._id.other));
    if (!other) continue;
    const base = {
      other: { id: other._id, name: other.name, avatar: other.avatar, role: other.role, online: realtime.isOnline(other._id) },
      lastMessage: messagePayload(r.last),
      unread: r.unread
    };
    if (r._id.tool) {
      const tool = toolMap.get(String(r._id.tool));
      if (!tool) continue;
      out.push({
        kind: 'tool',
        toolId: tool._id,
        toolName: tool.name,
        toolCategory: tool.category,
        toolImage: tool.images?.[0] || tool.image || '',
        ...base
      });
    } else {
      const job = jobMap.get(String(r._id.job));
      if (!job) continue;
      out.push({ kind: 'job', jobId: job._id, jobTitle: job.title, jobStatus: job.status, jobCategory: job.category, ...base });
    }
  }
  res.json(out);
});

router.get('/unread-count', authRequired, async (req, res) => {
  const count = await Message.countDocuments({ recipient: req.user._id, readAt: null });
  res.json({ count });
});

// ---- tool threads (customer ↔ supplier). Declared before /:jobId.

router.get('/tool/:toolId', authRequired, async (req, res) => {
  const tool = await loadTool(req.params.toolId);
  const other = await toolCounterpart(tool, req.user, req.query.with);
  const scope = { tool: tool._id };
  const msgs = await Message.find(threadFilter(scope, req.user._id, other)).sort({ createdAt: 1 }).limit(500);
  await markRead(scope, req.user._id, other);
  res.json(msgs.map(messagePayload));
});

router.post('/tool/:toolId/read', authRequired, async (req, res) => {
  const tool = await loadTool(req.params.toolId);
  const other = await toolCounterpart(tool, req.user, req.query.with || req.body?.with);
  await markRead({ tool: tool._id }, req.user._id, other);
  res.json({ ok: true });
});

router.post('/tool/:toolId', authRequired, upload.single('image'), async (req, res) => {
  try {
    const tool = await loadTool(req.params.toolId);
    const other = await toolCounterpart(tool, req.user, req.body.to || req.query.with);
    const text = String(req.body.text || '').trim();
    if (!text && !req.file) throw badRequest('Message cannot be empty');
    if (text.length > 2000) throw badRequest('Message is too long (max 2000 characters)');

    const msg = await Message.create({
      tool: tool._id,
      sender: req.user._id,
      recipient: other,
      text,
      image: req.file ? req.file.filename : ''
    });
    const payload = { ...messagePayload(msg), senderName: req.user.name, toolName: tool.name };
    realtime.emit(other, 'message:new', payload);
    realtime.emit(req.user._id, 'message:new', payload);
    res.status(201).json(messagePayload(msg));
  } catch (err) {
    discardUploads(req);
    throw err;
  }
});

// ---- job threads

// Thread history. Clients pass ?with=<technicianId> when the job has more
// than one technician they're talking to. Reading marks messages as read.
router.get('/:jobId', authRequired, async (req, res) => {
  const job = await loadJob(req.params.jobId);
  if (req.user.role === 'admin' && !req.query.with) {
    const all = await Message.find({ job: job._id }).sort({ createdAt: 1 });
    return res.json(all.map(messagePayload));
  }
  const other = counterpart(job, req.user, req.query.with);
  const msgs = await Message.find(threadFilter({ job: job._id }, req.user._id, other)).sort({ createdAt: 1 }).limit(500);
  await markRead({ job: job._id }, req.user._id, other);
  res.json(msgs.map(messagePayload));
});

router.post('/:jobId/read', authRequired, async (req, res) => {
  const job = await loadJob(req.params.jobId);
  const other = counterpart(job, req.user, req.query.with || req.body?.with);
  await markRead({ job: job._id }, req.user._id, other);
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
