const express = require('express');
const Message = require('../models/Message');
const Job = require('../models/Job');
const { authRequired } = require('../middleware/auth');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');

const router = express.Router();

function participants(job) {
  return [String(job.client), String(job.assignedTechnician || '')];
}

router.get('/:jobId', authRequired, async (req, res) => {
  const job = await Job.findById(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'Job not found' });
  if (!participants(job).includes(String(req.user._id)) && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Not a participant' });
  }
  const msgs = await Message.find({ job: job._id }).sort({ createdAt: 1 });
  res.json(msgs);
});

router.post('/:jobId', authRequired, async (req, res) => {
  const job = await Job.findById(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'Job not found' });
  const parts = participants(job);
  if (!parts.includes(String(req.user._id))) return res.status(403).json({ error: 'Not a participant' });
  const recipient = parts.find((p) => p && p !== String(req.user._id));
  if (!recipient) return res.status(400).json({ error: 'No counterparty (job not assigned yet)' });

  const msg = await Message.create({
    job: job._id,
    sender: req.user._id,
    recipient,
    text: req.body.text
  });
  await notify(recipient, 'message', 'New message', req.body.text.slice(0, 80), { jobId: job._id });
  // Push the message itself so the chat refreshes without waiting for the
  // next 5s poll. Both endpoints (sender + recipient) get it; sender's
  // local view ignores its own emits since it already optimistically
  // appended on send.
  const payload = {
    _id: msg._id,
    job: msg.job,
    sender: msg.sender,
    text: msg.text,
    createdAt: msg.createdAt
  };
  realtime.emit(recipient, 'message:new', payload);
  realtime.emit(req.user._id, 'message:new', payload);
  res.status(201).json(msg);
});

module.exports = router;
