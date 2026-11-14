const { connect, disconnect, makeUser } = require('./helpers');
const { point } = require('../src/utils/geo');

beforeAll(connect);
afterAll(disconnect);

// DHA Phase 5, Lahore, and points roughly 1, 6 and 30 km north of it.
const HOME = { lat: 31.463, lng: 74.408 };
const north = (km) => ({ lat: HOME.lat + km / 111.2, lng: HOME.lng });
const at = (p) => point(p.lat, p.lng);
const near = (p, extra = '') => `lat=${p.lat}&lng=${p.lng}${extra}`;

describe('near me', () => {
  let client;
  let close; // 1 km away, travels 15 km
  let mid; // 6 km away, travels only 3 km
  let far; // 30 km away
  let nowhere; // no location
  let supplier;

  beforeAll(async () => {
    client = await makeUser('client');
    const tech = (name, p, extra = {}) =>
      makeUser('technician', { profile: { name, skills: ['plumbing'], ...(p ? { geo: at(p), area: name } : {}), ...extra } });
    close = await tech('Close', north(1));
    mid = await tech('Mid', north(6), { serviceRadiusKm: 3 });
    far = await tech('Far', north(30), { serviceRadiusKm: 40 });
    nowhere = await tech('Nowhere', null);
    supplier = await makeUser('supplier', { profile: { address: 'Shop 1' } });
  });

  test('setting a location fills in the area and city; others never see the coordinates', async () => {
    await client.api('patch', '/api/users/me').send({ lat: 95, lng: 74 }).expect(400);
    await client.api('patch', '/api/users/me').send({ lat: 31.46 }).expect(400);
    const me = await client.api('patch', '/api/users/me').send({ ...HOME });
    expect(me.status).toBe(200);
    expect(me.body).toMatchObject({ area: 'DHA Phase 5', city: 'Lahore', geo: HOME });

    const seen = await supplier.api('get', `/api/users/${close.id}`);
    expect(seen.body.area).toBe('Close');
    expect(seen.body.geo).toBeUndefined();

    const cleared = await supplier.api('patch', '/api/users/me').send({ clearLocation: true });
    expect(cleared.body.geo).toBeNull();
  });

  test('technicians nearest first, with distance, radius and "travels this far" filters', async () => {
    const all = (await client.api('get', `/api/users/technicians?${near(HOME)}`)).body;
    expect(all.map((t) => t.name)).toEqual(['Close', 'Mid', 'Far', 'Nowhere']);
    expect(all[0].distanceKm).toBeCloseTo(1, 0);
    expect(all[1].distanceKm).toBeCloseTo(6, 0);
    expect(all[3].distanceKm).toBeNull();
    expect(all.every((t) => t.geo === undefined)).toBe(true);

    const within10 = (await client.api('get', `/api/users/technicians?${near(HOME, '&radius=10')}`)).body;
    expect(within10.map((t) => t.name)).toEqual(['Close', 'Mid']);

    // Mid only travels 3 km, so they don't cover a customer 6 km away.
    const covers = (await client.api('get', `/api/users/technicians?${near(HOME, '&radius=50&covers=1')}`)).body;
    expect(covers.map((t) => t.name)).toEqual(['Close', 'Far']);

    // Other sorts still work inside the radius; the public website can search too.
    const visitor = await require('./helpers').request(require('./helpers').app).get(`/api/users/technicians?${near(HOME, '&radius=10&sort=rating')}`);
    expect(visitor.body).toHaveLength(2);

    const profile = await client.api('get', `/api/users/${mid.id}`);
    expect(profile.body.distanceKm).toBeCloseTo(6, 0); // from the client's saved location
  });

  test("tools are at their supplier's shop", async () => {
    const tool = (await supplier.api('post', '/api/tools').send({ name: 'Drill', rentPricePerDay: 500 })).body;
    expect(tool.geo).toBeUndefined();
    const before = (await client.api('get', `/api/tools?${near(HOME)}`)).body.find((t) => t._id === tool._id);
    expect(before.distanceKm).toBeNull();

    await supplier.api('patch', '/api/users/me').send(north(2)).expect(200); // moves the shop and its tools
    const list = (await client.api('get', `/api/tools?${near(HOME, '&radius=5')}`)).body;
    expect(list.map((t) => t._id)).toContain(tool._id);
    expect(list[0].distanceKm).toBeCloseTo(2, 0);
    expect(list[0].area).toBeDefined();
    expect(list[0].geo).toBeUndefined();
    expect((await client.api('get', `/api/tools?${near(north(40), '&radius=5')}`)).body).toHaveLength(0);

    const detail = await client.api('get', `/api/tools/${tool._id}`);
    expect(detail.body.distanceKm).toBeCloseTo(2, 0);
  });

  test('technicians find jobs near them, and quotes are ranked with distance', async () => {
    const job = (
      await client.api('post', '/api/jobs').send({ title: 'Leaking tap', description: 'The kitchen tap drips all night.', category: 'plumbing' })
    ).body;
    expect(job.geo).toBeUndefined();
    expect(job.area).toBe('DHA Phase 5'); // from the client's saved location

    const elsewhere = (
      await client.api('post', '/api/jobs').send({ title: 'Fan repair', description: 'Ceiling fan hums and stops.', category: 'electrical', ...north(30) })
    ).body;

    const nearby = (await close.api('get', `/api/jobs?${near(north(1), '&radius=10')}`)).body.map((j) => j._id);
    expect(nearby).toContain(job._id);
    expect(nearby).not.toContain(elsewhere._id);
    const sorted = (await close.api('get', `/api/jobs?${near(north(1), '&sort=distance')}`)).body;
    expect(sorted[0]._id).toBe(job._id);
    expect(sorted[0].distanceKm).toBeCloseTo(1, 0);

    // A technician opening a job sees how far it is from their saved location.
    const seen = await far.api('get', `/api/jobs/${job._id}`);
    expect(seen.body.distanceKm).toBeCloseTo(30, 0);
    expect(seen.body.geo).toBeUndefined();

    await close.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 2500 }).expect(201);
    await far.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 2400 }).expect(201);
    const ranked = (await client.api('get', `/api/jobs/${job._id}/ranked-bids`)).body;
    const closeRow = ranked.find((r) => r.technicianId === close.id);
    expect(closeRow.reasons.some((r) => /km from you/.test(r))).toBe(true);
    expect(ranked.find((r) => r.technicianId === far.id).notes.some((n) => /30 km away/.test(n))).toBe(true);
    expect(ranked[0].technicianId).toBe(close.id);

    const match = (await client.api('post', '/api/ai/recommend').send({ description: 'leaking pipe', category: 'plumbing' })).body;
    expect(match.ranked[0].name).toBe('Close');
    expect(match.ranked[0].distanceKm).toBeCloseTo(1, 0);
  });

  test('the list of neighbourhoods is public', async () => {
    const areas = (await require('./helpers').request(require('./helpers').app).get('/api/meta/areas')).body;
    expect(areas.length).toBeGreaterThan(40);
    expect(areas.find((a) => a.city === 'Karachi' && a.name === 'Clifton')).toMatchObject({ lat: expect.any(Number), lng: expect.any(Number) });
  });
});
