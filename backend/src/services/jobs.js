// Job lifecycle rules shared by the job routes and the admin dispute tools:
// hiring, progress, completion, cancellation and what each one means for the
// escrowed payment and the technician's reliability stats.
const User = require('../models/User');
const wallet = require('./wallet');
const config = require('../config');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { JOB_STAGES } = require('../config/catalog');
const { badRequest, sameId } = require('../utils/http');

const HOUR_MS = 3600 * 1000;

// Stages before any work has been done: the client may still cancel and the
// technician may still withdraw.
const BEFORE_WORK = ['hired', 'on_the_way'];

const STAGE_LABEL = {
  hired: 'Hired',
  on_the_way: 'On the way',
  working: 'Work started',
  done: 'Work finished'
};

function autoCompleteAt(job) {
  if (job.status !== 'in_progress' || job.stage !== 'done' || !job.doneAt) return null;
  return new Date(new Date(job.doneAt).getTime() + config.autoConfirmHours * HOUR_MS);
}

async function tell(job, userIds, title, body, event = {}) {
  for (const id of userIds.filter(Boolean)) {
    await notify(id, 'job_status', title, body, { jobId: job._id });
    realtime.emit(id, 'job:status', { jobId: job._id, title: job.title, status: job.status, stage: job.stage, ...event });
  }
}

// The client picks a quote. `method` is how they'll pay: 'wallet' puts the
// money in escrow now; 'cash' is paid to the technician in person.
async function hire(job, bid, client, method) {
  const technician = await User.findOne({ _id: bid.technician, status: { $ne: 'suspended' } });
  if (!technician) throw badRequest('That technician is no longer available');

  job.agreedPrice = bid.amount;
  job.assignedTechnician = technician._id;
  await wallet.holdForJob(job, method); // throws 402 before anything is saved

  const losers = [];
  job.bids.forEach((b) => {
    if (sameId(b._id, bid._id)) b.status = 'accepted';
    else if (b.status === 'pending') {
      b.status = 'rejected';
      losers.push(b.technician);
    }
  });
  job.acceptedBid = bid._id;
  job.status = 'in_progress';
  job.stage = 'hired';
  job.hiredAt = new Date();
  job.log('hired', client._id, `Hired ${technician.name} for ${bid.amount} (${method === 'wallet' ? 'paid into escrow' : 'cash on completion'})`);
  try {
    await job.save();
  } catch (err) {
    await wallet.refundJob(job); // don't keep the client's money if the hire didn't stick
    throw err;
  }

  await User.updateOne({ _id: technician._id }, { $inc: { jobsAssigned: 1 } });
  await notify(technician._id, 'job_status', 'You got the job!', `You were hired for "${job.title}"`, { jobId: job._id });
  realtime.emit(technician._id, 'job:hired', { jobId: job._id, title: job.title, amount: bid.amount });
  for (const techId of losers) {
    await notify(techId, 'job_status', 'Job filled', `"${job.title}" went to another technician`, { jobId: job._id });
    realtime.emit(techId, 'job:status', { jobId: job._id, title: job.title, status: 'filled' });
  }
  return job;
}

// The technician reports progress. Stages only move forward.
async function advance(job, technician, stage, { note = '', images = [] } = {}) {
  if (job.status !== 'in_progress') throw badRequest('This job is not in progress');
  const from = JOB_STAGES.indexOf(job.stage);
  const to = JOB_STAGES.indexOf(stage);
  if (to <= from) throw badRequest(`This job is already at "${STAGE_LABEL[job.stage]}"`);

  job.stage = stage;
  if (stage === 'done') {
    job.doneAt = new Date();
    job.completionNote = note;
    job.completionImages = images;
  }
  job.log(stage, technician._id, note);
  await job.save();

  const body =
    stage === 'done'
      ? `${technician.name} finished "${job.title}". Please confirm so they get paid.`
      : `${technician.name}: ${STAGE_LABEL[stage].toLowerCase()} — "${job.title}"`;
  await tell(job, [job.client], stage === 'done' ? 'Work finished — please confirm' : STAGE_LABEL[stage], body);
  return job;
}

// The job is finished: pay the technician and count it.
async function complete(job, actor, note = '') {
  if (job.status !== 'in_progress') throw badRequest('Only a job in progress can be completed');
  await wallet.releaseJob(job);
  job.status = 'completed';
  job.stage = 'done';
  job.completedAt = new Date();
  if (!job.doneAt) job.doneAt = job.completedAt;
  job.log('completed', actor._id, note);
  await job.save();
  await User.updateOne({ _id: job.assignedTechnician }, { $inc: { jobsCompleted: 1 } });

  const paid = job.payment.status === 'released' ? ` ${job.payment.net} was added to your wallet.` : '';
  if (!sameId(actor._id, job.assignedTechnician)) {
    await tell(job, [job.assignedTechnician], 'Job completed', `"${job.title}" was confirmed as complete.${paid}`);
  }
  if (!sameId(actor._id, job.client)) {
    await tell(job, [job.client], 'Job completed', `"${job.title}" is complete. How did it go? Leave a review.`);
  }
  return job;
}

// Stops a job. Escrow goes back to the client. `technicianAtFault` keeps the
// hire on the technician's record (it lowers their completion rate).
async function cancel(job, actor, reason = '', { technicianAtFault = false } = {}) {
  if (!['pending', 'in_progress'].includes(job.status)) throw badRequest(`This job is already ${job.status}`);
  const wasHired = job.status === 'in_progress';
  await wallet.refundJob(job);
  job.status = 'cancelled';
  job.cancelledAt = new Date();
  job.cancelReason = reason;
  job.log('cancelled', actor._id, reason);
  await job.save();
  if (wasHired && !technicianAtFault) {
    await User.updateOne({ _id: job.assignedTechnician, jobsAssigned: { $gt: 0 } }, { $inc: { jobsAssigned: -1 } });
  }

  const refunded = job.payment.status === 'refunded' ? ` ${job.payment.amount} was returned to the client's wallet.` : '';
  const others = [job.client, job.assignedTechnician, job.requestedTechnician, ...job.bids.filter((b) => b.status === 'pending').map((b) => b.technician)];
  const unique = [...new Set(others.filter((u) => u && !sameId(u, actor._id)).map(String))];
  await tell(job, unique, 'Job cancelled', `"${job.title}" was cancelled.${reason ? ` Reason: ${reason}` : ''}${refunded}`);
  return job;
}

// The hired technician backs out before starting: the client is refunded and
// the job goes back to collecting quotes.
async function withdraw(job, technician, reason = '') {
  if (job.status !== 'in_progress') throw badRequest('This job is not in progress');
  if (!BEFORE_WORK.includes(job.stage)) throw badRequest('Work has already started — finish the job or contact support');
  await wallet.refundJob(job);

  job.bids.forEach((b) => {
    if (sameId(b.technician, technician._id)) b.status = 'withdrawn';
    else if (b.status === 'rejected') b.status = 'pending';
  });
  if (sameId(job.requestedTechnician, technician._id)) job.requestDeclined = true;
  job.status = 'pending';
  job.stage = 'hired';
  job.assignedTechnician = null;
  job.acceptedBid = null;
  job.agreedPrice = null;
  job.hiredAt = null;
  job.log('technician_withdrew', technician._id, reason);
  await job.save();

  await notify(
    job.client,
    'job_status',
    'Technician withdrew',
    `${technician.name} can no longer do "${job.title}".${job.payment.status === 'refunded' ? ' Your payment was refunded.' : ''} Your job is open for quotes again.`,
    { jobId: job._id }
  );
  realtime.emit(job.client, 'job:status', { jobId: job._id, title: job.title, status: 'pending', stage: 'reopened' });
  return job;
}

const isOpenMarketJob = (job) => job.status === 'pending' && !job.requestedTechnician;

function announce(job) {
  realtime.emitRole('technician', 'job:new', {
    jobId: job._id,
    title: job.title,
    category: job.category,
    budget: job.budget,
    city: job.city,
    urgency: job.urgency
  });
}

module.exports = { BEFORE_WORK, STAGE_LABEL, autoCompleteAt, hire, advance, complete, cancel, withdraw, isOpenMarketJob, announce };
