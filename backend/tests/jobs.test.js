const { connect, disconnect, makeUser } = require('./helpers');
const User = require('../src/models/User');

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

describe('job lifecycle', () => {
  let client;
  let plumber;
  let painter;
  let outsider;

  beforeAll(async () => {
    client = await makeUser('client', { register: { city: 'Lahore' } });
    plumber = await makeUser('technician', {
      profile: { skills: ['plumbing'], city: 'Lahore', rating: 4.8, ratingCount: 10, jobsCompleted: 10, jobsAssigned: 10, kycStatus: 'approved' }
    });
    painter = await makeUser('technician', { profile: { skills: ['painting'], city: 'Karachi' } });
    outsider = await makeUser('client');
  });

  test('validation: title and description are required', async () => {
    const res = await client.api('post', '/api/jobs').send({ title: 'x' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Title/);
  });

  test('only clients can post jobs', async () => {
    const res = await plumber.api('post', '/api/jobs').send({ title: 'Something', description: 'A long enough description' });
    expect(res.status).toBe(403);
  });

  test('full flow: post → bid → AI-ranked bids → accept → complete → rate', async () => {
    const job = await postJob(client);
    expect(job.status).toBe('pending');
    expect(job.history[0].status).toBe('pending');

    // Open marketplace shows it to technicians.
    const open = await plumber.api('get', '/api/jobs');
    expect(open.body.map((j) => j._id)).toContain(job._id);

    await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 2800, etaDays: 1, message: 'Today' }).expect(201);
    await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 3500, etaDays: 2 }).expect(201);
    const dup = await plumber.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 2000 });
    expect(dup.status).toBe(409);
    const zero = await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 0 });
    expect(zero.status).toBe(400);

    // Bidding records responsiveness for the ranker.
    const plumberDoc = await User.findById(plumber.id);
    expect(plumberDoc.responseSamples).toBe(1);

    const ranked = await client.api('get', `/api/jobs/${job._id}/ranked-bids`);
    expect(ranked.status).toBe(200);
    expect(ranked.body).toHaveLength(2);
    expect(ranked.body[0].technicianId).toBe(plumber.id);
    expect(ranked.body[0].matchPercent).toBeGreaterThan(ranked.body[1].matchPercent);
    expect(ranked.body[0].reasons).toEqual(expect.arrayContaining(['Specialises in plumbing', 'Lowest bid']));
    expect(ranked.body[0].engine).toBe('fallback');
    expect(ranked.body[1].notes.join(' ')).toMatch(/over your budget/);

    // Only the owner sees the ranking.
    await outsider.api('get', `/api/jobs/${job._id}/ranked-bids`).expect(403);

    const bidId = ranked.body[0].bidId;
    const accepted = await client.api('post', `/api/jobs/${job._id}/accept/${bidId}`);
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('in_progress');
    expect(accepted.body.agreedPrice).toBe(2800);
    const loser = accepted.body.bids.find((b) => b.technician === painter.id);
    expect(loser.status).toBe('rejected');

    // Can't hire twice.
    await client.api('post', `/api/jobs/${job._id}/accept/${bidId}`).expect(400);

    // Illegal transitions are rejected.
    await plumber.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'pending' }).expect(400);
    await plumber.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'cancelled' }).expect(403);
    await painter.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'completed' }).expect(403);

    // Contact details are shared only between hired parties.
    const asTech = await plumber.api('get', `/api/jobs/${job._id}`);
    expect(asTech.body.client.email).toBeTruthy();
    const asLoser = await painter.api('get', `/api/jobs/${job._id}`);
    expect(asLoser.status).toBe(200);
    expect(asLoser.body.client.email).toBeUndefined();

    const done = await plumber.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'completed' });
    expect(done.status).toBe(200);
    // Completing twice must not double-count.
    await client.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'completed' }).expect(400);
    const after = await User.findById(plumber.id);
    expect(after.jobsCompleted).toBe(11);
    expect(after.jobsAssigned).toBe(11);

    await client.api('post', `/api/jobs/${job._id}/rate`).send({ rating: 6 }).expect(400);
    const rated = await client.api('post', `/api/jobs/${job._id}/rate`).send({ rating: 5, review: 'Great work' });
    expect(rated.status).toBe(200);
    await client.api('post', `/api/jobs/${job._id}/rate`).send({ rating: 4 }).expect(409);
    const ratedTech = await User.findById(plumber.id);
    expect(ratedTech.ratingCount).toBe(11);

    const detail = await client.api('get', `/api/jobs/${job._id}`);
    expect(detail.body.history.map((h) => h.status)).toEqual(
      expect.arrayContaining(['pending', 'bid', 'in_progress', 'completed', 'rated'])
    );

    const reviews = await outsider.api('get', `/api/reviews/technician/${plumber.id}`);
    expect(reviews.body[0]).toMatchObject({ rating: 5, review: 'Great work' });
    const summary = await outsider.api('get', `/api/reviews/technician/${plumber.id}/summary`);
    expect(summary.body).toMatchObject({ count: 1, average: 5 });
    expect(summary.body.distribution['5']).toBe(1);
  });

  test('direct service request is private until opened to everyone', async () => {
    const job = await postJob(client, { title: 'Replace bathroom tap', requestedTechnician: plumber.id });
    expect(job.requestedTechnician).toBe(plumber.id);

    const openForPainter = await painter.api('get', '/api/jobs');
    expect(openForPainter.body.map((j) => j._id)).not.toContain(job._id);
    await painter.api('get', `/api/jobs/${job._id}`).expect(403);
    await painter.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 100 }).expect(403);

    const requests = await plumber.api('get', '/api/jobs?view=requests');
    expect(requests.body.map((j) => j._id)).toContain(job._id);

    await painter.api('post', `/api/jobs/${job._id}/decline`).expect(403);
    const declined = await plumber.api('post', `/api/jobs/${job._id}/decline`).send({ reason: 'Fully booked' });
    expect(declined.body.requestDeclined).toBe(true);

    await outsider.api('post', `/api/jobs/${job._id}/open`).expect(403);
    const opened = await client.api('post', `/api/jobs/${job._id}/open`);
    expect(opened.body.requestedTechnician).toBeNull();
    const nowOpen = await painter.api('get', '/api/jobs');
    expect(nowOpen.body.map((j) => j._id)).toContain(job._id);
  });

  test('client can cancel a pending job with a reason; technicians cannot', async () => {
    const job = await postJob(client, { title: 'Paint the fence' });
    const res = await client.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'cancelled', note: 'Changed my mind' });
    expect(res.status).toBe(200);
    expect(res.body.cancelReason).toBe('Changed my mind');
    await client.api('patch', `/api/jobs/${job._id}/status`).send({ status: 'cancelled' }).expect(400);
  });

  test('search and filters on the open marketplace', async () => {
    await postJob(client, { title: 'Ceiling fan wobbling', category: 'electrical', description: 'The fan wobbles at high speed.' });
    const byText = await painter.api('get', '/api/jobs?q=wobbl');
    expect(byText.body).toHaveLength(1);
    const byCat = await painter.api('get', '/api/jobs?category=electrical');
    expect(byCat.body.every((j) => j.category === 'electrical')).toBe(true);
    const matching = await plumber.api('get', '/api/jobs?matching=1');
    expect(matching.body.every((j) => j.category === 'plumbing')).toBe(true);
  });

  test('clients only list their own jobs and malformed ids are 404s', async () => {
    const mine = await outsider.api('get', '/api/jobs');
    expect(mine.body).toHaveLength(0);
    await client.api('get', '/api/jobs/not-an-id').expect(404);
  });
});
