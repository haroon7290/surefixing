const { connect, disconnect, makeUser } = require('./helpers');
const scoring = require('../src/services/scoring');
const User = require('../src/models/User');

describe('fallback text analysis', () => {
  test.each([
    ['Water is leaking from the pipe under my kitchen sink', 'plumbing'],
    ['Sparks coming out of the socket and the breaker keeps tripping', 'electrical'],
    ['The split AC is not cooling and needs a gas refill', 'hvac'],
    ['Washing machine stopped spinning', 'appliance'],
    ['Need the bedroom walls repainted with two coats', 'painting'],
    ['Cockroaches and termites in the kitchen cupboards', 'pest_control'],
    ['I am locked out, lost my house key', 'locksmith']
  ])('%s → %s', (text, category) => {
    expect(scoring.analyze(text).category).toBe(category);
  });

  test('urgency detection, including negations', () => {
    expect(scoring.detectUrgency('Pipe burst and the kitchen is flooding').urgency).toBe('emergency');
    expect(scoring.detectUrgency('Sink is leaking, please come today').urgency).toBe('high');
    expect(scoring.detectUrgency('Not urgent, paint the gate next week').urgency).toBe('low');
    expect(scoring.detectUrgency('Install a shelf').urgency).toBe('normal');
  });

  test('unknown text falls back to general with low confidence', () => {
    const a = scoring.analyze('hello there');
    expect(a.category).toBe('general');
    expect(a.confidence).toBeLessThan(0.5);
  });

  test('stemmer normalises common word forms', () => {
    expect(scoring.stem('leaking')).toBe('leak');
    expect(scoring.stem('pipes')).toBe('pipe');
    expect(scoring.stem('clogged')).toBe('clog');
    expect(scoring.stem('batteries')).toBe('battery');
  });
});

describe('fallback scoring', () => {
  const base = { rating: 4.5, ratingCount: 10, jobsCompleted: 10, jobsAssigned: 10, avgResponseMinutes: 30, city: 'Lahore' };

  test('specialists outrank generalists for the same stats', () => {
    const { ranked } = scoring.recommend(
      [
        { ...base, technicianId: 'a', skills: ['painting'] },
        { ...base, technicianId: 'b', skills: ['plumbing'] }
      ],
      { description: 'leaking pipe under the sink', city: 'Lahore' }
    );
    expect(ranked[0].technicianId).toBe('b');
    expect(ranked[0].reasons).toContain('Specialises in plumbing');
    expect(ranked[0].matchPercent).toBeGreaterThan(0);
    expect(ranked[0].matchPercent).toBeLessThanOrEqual(100);
  });

  test('few reviews are damped by the Bayesian prior', () => {
    const one = scoring.scoreOne({ ...base, rating: 5, ratingCount: 1 }, {}, 'recommend');
    const many = scoring.scoreOne({ ...base, rating: 4.8, ratingCount: 40 }, {}, 'recommend');
    expect(many.breakdown.rating).toBeGreaterThan(one.breakdown.rating);
  });

  test('urgent requests favour fast responders', () => {
    const fast = { ...base, technicianId: 'fast', skills: ['plumbing'], avgResponseMinutes: 5, rating: 4.2 };
    const slow = { ...base, technicianId: 'slow', skills: ['plumbing'], avgResponseMinutes: 240, rating: 4.6 };
    const normal = scoring.recommend([fast, slow], { category: 'plumbing', urgency: 'low' });
    const urgent = scoring.recommend([fast, slow], { category: 'plumbing', urgency: 'emergency' });
    const gap = (r) => r.ranked.find((x) => x.technicianId === 'fast').score - r.ranked.find((x) => x.technicianId === 'slow').score;
    expect(gap(urgent)).toBeGreaterThan(gap(normal));
  });

  test('bid ranking rewards cheaper bids within budget', () => {
    const ranked = scoring.rankBids(
      [
        { ...base, technicianId: 'cheap', skills: ['plumbing'], amount: 1000 },
        { ...base, technicianId: 'pricey', skills: ['plumbing'], amount: 3000 }
      ],
      { jobCategory: 'plumbing', budget: 2000 }
    );
    expect(ranked[0].technicianId).toBe('cheap');
    expect(ranked[0].reasons).toContain('Lowest bid');
    expect(ranked[1].notes).toContain('50% over your budget');
  });
});

describe('AI routes (fallback engine)', () => {
  beforeAll(connect);
  afterAll(disconnect);

  test('analyze + recommend', async () => {
    const client = await makeUser('client', { register: { city: 'Lahore' } });
    await makeUser('technician', { profile: { skills: ['electrical'], city: 'Lahore', rating: 4.9, ratingCount: 30 } });
    const plumber = await makeUser('technician', { profile: { skills: ['plumbing'], city: 'Lahore', rating: 4.2, ratingCount: 5 } });
    const banned = await makeUser('technician', { profile: { skills: ['plumbing'] } });
    await User.updateOne({ _id: banned.id }, { $set: { status: 'suspended' } });

    const a = await client.api('post', '/api/ai/analyze').send({ text: 'my toilet is clogged and overflowing' });
    expect(a.status).toBe(200);
    expect(a.body).toMatchObject({ category: 'plumbing', urgency: 'high', engine: 'fallback' });

    const r = await client.api('post', '/api/ai/recommend').send({ description: 'my toilet is clogged and overflowing' });
    expect(r.status).toBe(200);
    expect(r.body.category).toBe('plumbing');
    expect(r.body.total).toBe(2); // suspended technician excluded
    expect(r.body.ranked[0].technicianId).toBe(plumber.id);

    await client.api('post', '/api/ai/recommend').send({}).expect(400);
    const status = await client.api('get', '/api/ai/status');
    expect(status.body.online).toBe(false);
  });
});
