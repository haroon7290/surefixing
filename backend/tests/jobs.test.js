const { connect, disconnect, makeUser } = require('./helpers');
const User = require('../src/models/User');
const Job = require('../src/models/Job');

beforeAll(connect);
afterAll(disconnect);

async function postJob(client, overrides = {}) {
  const res = await client.api('post', '/api/jobs').send({
    title: 'Fix leaking kitchen sink',
    description: 'Water is leaking from the pipe under the sink.',
    category: 'plumbing',
    budget: 3000,
    city: 'Lahore',
    urgency: 'high',
    ...overrides
  });
  if (res.status !== 201) throw new Error(`post job failed ${res.status} ${JSON.stringify(res.body)}`);
  return res.body;
}

// Posts a job, has `tech` quote on it and the client hire them.
async function hired(client, tech, { amount = 2000, paymentMethod = 'cash', ...job } = {}) {
  const posted = await postJob(client, job);
  const quoted = await tech.api('post', `/api/jobs/${posted._id}/bids`).send({ amount });
  const res = await client.api('post', `/api/jobs/${posted._id}/accept/${quoted.body.bids[0]._id}`).send({ paymentMethod });
  if (res.status !== 200) throw new Error(`hire failed ${res.status} ${JSON.stringify(res.body)}`);
  return res.body;
}

const stats = async (user) => User.findById(user.id).select('jobsAssigned jobsCompleted walletBalance ratingCount responseSamples');

describe('job lifecycle', () => {
  let client;
  let plumber;
  let painter;
  let outsider;
  let admin;

  beforeAll(async () => {
    client = await makeUser('client', { register: { city: 'Lahore' } });
    plumber = await makeUser('technician', {
      profile: { skills: ['plumbing'], city: 'Lahore', rating: 4.8, ratingCount: 10, jobsCompleted: 10, jobsAssigned: 10, kycStatus: 'approved' }
    });
    painter = await makeUser('technician', { profile: { skills: ['painting'], city: 'Karachi' } });
    outsider = await makeUser('client');
    admin = await makeUser('admin');
  });

  test('validation: title and description are required; only clients post', async () => {
    const res = await client.api('post', '/api/jobs').send({ title: 'x' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Title/);
    await plumber.api('post', '/api/jobs').send({ title: 'Something', description: 'A long enough description' }).expect(403);
  });

  test('full flow: post → quotes → AI ranking → hire → progress → confirm → review', async () => {
    const job = await postJob(client);
    expect(job).toMatchObject({ status: 'pending', bidCount: 0 });
    expect(job.history[0].event).toBe('posted');

    const open = await plumber.api('get', '/api/jobs');
    expect(open.body.map((j) => j._id)).toContain(job._id);

    await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 2800, etaDays: 1, message: 'Today' }).expect(201);
    await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 3500, etaDays: 2 }).expect(201);
    await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 2000 }).expect(409);
    await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 0 }).expect(400);
    expect((await stats(plumber)).responseSamples).toBe(1); // quoting records responsiveness

    // A technician sees how many quotes there are, but only their own price.
    const market = await painter.api('get', `/api/jobs/${job._id}`);
    expect(market.body.bidCount).toBe(2);
    expect(market.body.bids).toHaveLength(1);
    expect(market.body.bids[0].amount).toBe(3500);

    const ranked = await client.api('get', `/api/jobs/${job._id}/ranked-bids`);
    expect(ranked.body).toHaveLength(2);
    expect(ranked.body[0].technicianId).toBe(plumber.id);
    expect(ranked.body[0].matchPercent).toBeGreaterThan(ranked.body[1].matchPercent);
    expect(ranked.body[0].reasons).toEqual(expect.arrayContaining(['Specialises in plumbing', 'Lowest bid']));
    expect(ranked.body[1].notes.join(' ')).toMatch(/over your budget/);
    await outsider.api('get', `/api/jobs/${job._id}/ranked-bids`).expect(403);

    const bidId = ranked.body[0].bidId;
    const accepted = await client.api('post', `/api/jobs/${job._id}/accept/${bidId}`).send({ paymentMethod: 'cash' });
    expect(accepted.body).toMatchObject({ status: 'in_progress', stage: 'hired', agreedPrice: 2800 });
    expect(accepted.body.payment).toMatchObject({ method: 'cash', status: 'cash_due', amount: 2800 });
    expect(accepted.body.bids.find((b) => b.technician._id === painter.id).status).toBe('rejected');
    await client.api('post', `/api/jobs/${job._id}/accept/${bidId}`).expect(400); // can't hire twice

    // Contact details are shared only between the hired parties.
    expect((await plumber.api('get', `/api/jobs/${job._id}`)).body.client.email).toBeTruthy();
    const asLoser = await painter.api('get', `/api/jobs/${job._id}`);
    expect(asLoser.body.client.email).toBeUndefined();
    expect(asLoser.body.payment).toBeUndefined();

    // Progress moves forward only, and only the hired technician reports it.
    await painter.api('patch', `/api/jobs/${job._id}/stage`).send({ stage: 'working' }).expect(403);
    await plumber.api('post', `/api/jobs/${job._id}/complete`).expect(400); // not finished yet
    expect((await plumber.api('patch', `/api/jobs/${job._id}/stage`).send({ stage: 'on_the_way' })).body.stage).toBe('on_the_way');
    expect((await plumber.api('patch', `/api/jobs/${job._id}/stage`).send({ stage: 'working' })).body.stage).toBe('working');
    await plumber.api('patch', `/api/jobs/${job._id}/stage`).send({ stage: 'on_the_way' }).expect(400);

    const done = await plumber.api('post', `/api/jobs/${job._id}/done`).send({ note: 'Replaced the trap and tested for leaks.' });
    expect(done.body).toMatchObject({ status: 'in_progress', stage: 'done', completionNote: 'Replaced the trap and tested for leaks.' });
    expect(new Date(done.body.autoCompleteAt).getTime()).toBeGreaterThan(Date.now());
    // The technician can't close the job while the client still has time to confirm.
    await plumber.api('post', `/api/jobs/${job._id}/complete`).expect(400);
    await outsider.api('post', `/api/jobs/${job._id}/complete`).expect(403);

    const confirmed = await client.api('post', `/api/jobs/${job._id}/complete`);
    expect(confirmed.body.status).toBe('completed');
    expect(confirmed.body.payment.status).toBe('cash_paid');
    await client.api('post', `/api/jobs/${job._id}/complete`).expect(400); // no double counting
    expect(await stats(plumber)).toMatchObject({ jobsCompleted: 11, jobsAssigned: 11 });

    await client.api('post', `/api/jobs/${job._id}/rate`).send({ rating: 6 }).expect(400);
    await client.api('post', `/api/jobs/${job._id}/rate`).send({ rating: 5, review: 'Great work' }).expect(200);
    await client.api('post', `/api/jobs/${job._id}/rate`).send({ rating: 4 }).expect(409);
    expect((await stats(plumber)).ratingCount).toBe(11);

    const detail = await client.api('get', `/api/jobs/${job._id}`);
    expect(detail.body.history.map((h) => h.event)).toEqual(
      expect.arrayContaining(['posted', 'bid', 'hired', 'on_the_way', 'working', 'done', 'completed', 'rated'])
    );
    const reviews = await outsider.api('get', `/api/reviews/technician/${plumber.id}`);
    expect(reviews.body[0]).toMatchObject({ rating: 5, review: 'Great work' });
    const summary = await outsider.api('get', `/api/reviews/technician/${plumber.id}/summary`);
    expect(summary.body).toMatchObject({ count: 1, average: 5 });
  });

  test('wallet escrow: held on hire, released minus the fee on confirmation', async () => {
    const job = await postJob(client, { title: 'Unblock bathroom drain' });
    const quote = await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 3000 });
    const bidId = quote.body.bids[0]._id;

    // Not enough money: nothing is hired and nothing is taken.
    const short = await client.api('post', `/api/jobs/${job._id}/accept/${bidId}`).send({ paymentMethod: 'wallet' });
    expect(short.status).toBe(402);
    expect(short.body).toMatchObject({ code: 'insufficient_funds', details: { needed: 3000, balance: 0 } });
    expect((await Job.findById(job._id)).status).toBe('pending');

    await client.api('post', '/api/wallet/topup').send({ amount: 5000 }).expect(201);
    const hiredJob = await client.api('post', `/api/jobs/${job._id}/accept/${bidId}`).send({ paymentMethod: 'wallet' });
    expect(hiredJob.body.payment).toMatchObject({ method: 'wallet', status: 'held', amount: 3000, fee: 300, net: 2700 });
    expect((await stats(client)).walletBalance).toBe(2000);
    expect((await client.api('get', '/api/wallet')).body).toMatchObject({ balance: 2000, held: 3000 });
    expect((await plumber.api('get', '/api/wallet')).body).toMatchObject({ balance: 0, incoming: 2700 });

    await plumber.api('post', `/api/jobs/${job._id}/done`).send({}).expect(200);
    const before = (await stats(plumber)).walletBalance;
    const confirmed = await client.api('post', `/api/jobs/${job._id}/complete`);
    expect(confirmed.body.payment.status).toBe('released');
    expect((await stats(plumber)).walletBalance).toBe(before + 2700);

    const wallet = await plumber.api('get', '/api/wallet');
    expect(wallet.body.recent[0]).toMatchObject({ type: 'job_earning', amount: 2700 });
    const fees = await admin.api('get', '/api/admin/transactions?type=platform_fee');
    expect(fees.body[0]).toMatchObject({ amount: 300, user: null });
    expect((await admin.api('get', '/api/admin/stats')).body.platformRevenue).toBe(300);
  });

  test('a technician may close a finished job once the client has had time to confirm', async () => {
    const job = await hired(client, plumber, { title: 'Fix running toilet' });
    await plumber.api('post', `/api/jobs/${job._id}/done`).send({}).expect(200);
    await plumber.api('post', `/api/jobs/${job._id}/complete`).expect(400);
    await Job.updateOne({ _id: job._id }, { $set: { doneAt: new Date(Date.now() - 73 * 3600 * 1000) } });
    const closed = await plumber.api('post', `/api/jobs/${job._id}/complete`);
    expect(closed.body.status).toBe('completed');
  });

  test('cancelling: free before work starts (refunded, no penalty), blocked after', async () => {
    await client.api('post', '/api/wallet/topup').send({ amount: 4000 }).expect(201);
    const balance = (await stats(client)).walletBalance;
    const assigned = (await stats(plumber)).jobsAssigned;

    const job = await hired(client, plumber, { title: 'Install water filter', amount: 2500, paymentMethod: 'wallet' });
    expect((await stats(client)).walletBalance).toBe(balance - 2500);
    expect((await stats(plumber)).jobsAssigned).toBe(assigned + 1);

    await plumber.api('post', `/api/jobs/${job._id}/cancel`).send({ reason: 'x' }).expect(403);
    const cancelled = await client.api('post', `/api/jobs/${job._id}/cancel`).send({ reason: 'Found the leak myself' });
    expect(cancelled.body).toMatchObject({ status: 'cancelled', cancelReason: 'Found the leak myself' });
    expect(cancelled.body.payment.status).toBe('refunded');
    expect((await stats(client)).walletBalance).toBe(balance);
    expect((await stats(plumber)).jobsAssigned).toBe(assigned); // not the technician's fault
    await client.api('post', `/api/jobs/${job._id}/cancel`).expect(400);

    // Once work has started the client can't just walk away…
    const started = await hired(client, plumber, { title: 'Replace mixer tap', paymentMethod: 'wallet' });
    await plumber.api('patch', `/api/jobs/${started._id}/stage`).send({ stage: 'working' }).expect(200);
    const blocked = await client.api('post', `/api/jobs/${started._id}/cancel`).send({ reason: 'Changed my mind' });
    expect(blocked.status).toBe(400);
    expect(blocked.body.error).toMatch(/report a problem/i);
    // …but support can settle the dispute either way.
    const refunded = await admin.api('post', `/api/admin/jobs/${started._id}/resolve`).send({ action: 'refund', note: 'Technician left the job unfinished', technicianAtFault: true });
    expect(refunded.body.status).toBe('cancelled');
    expect((await stats(client)).walletBalance).toBe(balance);
    expect((await stats(plumber)).jobsAssigned).toBe(assigned + 1); // stays on their record

    const disputed = await hired(client, plumber, { title: 'Fix shower pressure' });
    const released = await admin.api('post', `/api/admin/jobs/${disputed._id}/resolve`).send({ action: 'release' });
    expect(released.body.status).toBe('completed');
  });

  test('a hired technician can withdraw before starting: refund, and the job reopens', async () => {
    await client.api('post', '/api/wallet/topup').send({ amount: 3000 }).expect(201);
    const balance = (await stats(client)).walletBalance;
    const job = await postJob(client, { title: 'Repair garden tap' });
    const a = await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 1500 });
    await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 1800 }).expect(201);
    await client.api('post', `/api/jobs/${job._id}/accept/${a.body.bids[0]._id}`).send({ paymentMethod: 'wallet' }).expect(200);

    await painter.api('post', `/api/jobs/${job._id}/withdraw`).expect(403);
    await plumber.api('post', `/api/jobs/${job._id}/withdraw`).send({ reason: 'Van broke down' }).expect(200);
    expect((await stats(client)).walletBalance).toBe(balance);

    const reopened = await client.api('get', `/api/jobs/${job._id}`);
    expect(reopened.body).toMatchObject({ status: 'pending', assignedTechnician: null, agreedPrice: null });
    const byTech = Object.fromEntries(reopened.body.bids.map((b) => [b.technician._id, b.status]));
    expect(byTech[plumber.id]).toBe('withdrawn');
    expect(byTech[painter.id]).toBe('pending'); // the other quote is live again
    await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 1400 }).expect(409);

    // After work has started there is no backing out.
    const started = await hired(client, plumber, { title: 'Fix kitchen drain' });
    await plumber.api('patch', `/api/jobs/${started._id}/stage`).send({ stage: 'working' }).expect(200);
    await plumber.api('post', `/api/jobs/${started._id}/withdraw`).expect(400);
  });

  test('direct service request is private until opened to everyone', async () => {
    const job = await postJob(client, { title: 'Replace bathroom tap', requestedTechnician: plumber.id });
    expect(job.requestedTechnician._id).toBe(plumber.id);

    expect((await painter.api('get', '/api/jobs')).body.map((j) => j._id)).not.toContain(job._id);
    await painter.api('get', `/api/jobs/${job._id}`).expect(403);
    await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 100 }).expect(403);
    expect((await plumber.api('get', '/api/jobs?view=requests')).body.map((j) => j._id)).toContain(job._id);

    await painter.api('post', `/api/jobs/${job._id}/decline`).expect(403);
    const declined = await plumber.api('post', `/api/jobs/${job._id}/decline`).send({ reason: 'Fully booked' });
    expect(declined.body.requestDeclined).toBe(true);

    await outsider.api('post', `/api/jobs/${job._id}/open`).expect(403);
    const opened = await client.api('post', `/api/jobs/${job._id}/open`);
    expect(opened.body.requestedTechnician).toBeNull();
    expect((await painter.api('get', '/api/jobs')).body.map((j) => j._id)).toContain(job._id);
  });

  test('client can cancel a pending job with a reason', async () => {
    const job = await postJob(client, { title: 'Paint the fence' });
    const res = await client.api('post', `/api/jobs/${job._id}/cancel`).send({ reason: 'Changed my mind' });
    expect(res.body).toMatchObject({ status: 'cancelled', cancelReason: 'Changed my mind' });
    await client.api('post', `/api/jobs/${job._id}/cancel`).expect(400);
  });

  test('search and filters on the open marketplace', async () => {
    await postJob(client, { title: 'Ceiling fan wobbling', category: 'electrical', description: 'The fan wobbles at high speed.' });
    expect((await painter.api('get', '/api/jobs?q=wobbl')).body).toHaveLength(1);
    expect((await painter.api('get', '/api/jobs?category=electrical')).body.every((j) => j.category === 'electrical')).toBe(true);
    expect((await plumber.api('get', '/api/jobs?matching=1')).body.every((j) => j.category === 'plumbing')).toBe(true);
  });

  test('clients only list their own jobs and malformed ids are 404s', async () => {
    expect((await outsider.api('get', '/api/jobs')).body).toHaveLength(0);
    await client.api('get', '/api/jobs/not-an-id').expect(404);
  });

  test('dashboard summaries reflect the work above', async () => {
    const mine = await client.api('get', '/api/users/me/summary');
    expect(mine.body.jobs.completed).toBeGreaterThanOrEqual(3);
    expect(mine.body).toHaveProperty('walletBalance');
    const tech = await plumber.api('get', '/api/users/me/summary');
    expect(tech.body.completedJobs).toBeGreaterThanOrEqual(3);
    expect(tech.body.earnings).toBeGreaterThan(0);
  });
});
