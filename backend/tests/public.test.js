const { app, request, connect, disconnect, makeUser } = require('./helpers');

beforeAll(connect);
afterAll(disconnect);

// The website lets visitors browse before signing up.
describe('public (signed-out) access', () => {
  let client;
  let tech;
  let supplier;
  let toolId;

  beforeAll(async () => {
    client = await makeUser('client');
    tech = await makeUser('technician', { profile: { skills: ['plumbing'], city: 'Lahore' } });
    supplier = await makeUser('supplier');
    const tool = await supplier.api('post', '/api/tools').send({ name: 'Hammer drill', rentPricePerDay: 500, stock: 2 });
    toolId = tool.body._id || tool.body.id;
  });

  test('technician directory and profiles are public, without contact details', async () => {
    const list = await request(app).get('/api/users/technicians').expect(200);
    expect(list.body.map((t) => t.id)).toContain(tech.id);
    expect(list.body[0].email).toBeUndefined();

    const profile = await request(app).get(`/api/users/${tech.id}`).expect(200);
    expect(profile.body.name).toBeTruthy();
    expect(profile.body.email).toBeUndefined();
    expect(profile.body.phone).toBeUndefined();

    await request(app).get(`/api/reviews/technician/${tech.id}`).expect(200);
    await request(app).get(`/api/reviews/technician/${tech.id}/summary`).expect(200);
  });

  test('client and admin profiles stay private to visitors', async () => {
    await request(app).get(`/api/users/${client.id}`).expect(404);
    await client.api('get', `/api/users/${client.id}`).expect(200);
  });

  test('tool catalogue is public', async () => {
    const list = await request(app).get('/api/tools').expect(200);
    expect(list.body.length).toBeGreaterThan(0);
    await request(app).get(`/api/tools/${toolId}`).expect(200);
    // ?mine=1 means nothing without a supplier session.
    const mine = await request(app).get('/api/tools?mine=1').expect(200);
    expect(mine.body.every((t) => t.available)).toBe(true);
  });

  test('a bad token is still rejected on public routes', async () => {
    await request(app).get('/api/tools').set('Authorization', 'Bearer nope').expect(401);
  });

  test('problem analysis works signed out; matching and writes do not', async () => {
    const res = await request(app).post('/api/ai/analyze').send({ text: 'kitchen tap is leaking water' }).expect(200);
    expect(res.body.category).toBe('plumbing');
    await request(app).post('/api/ai/recommend').send({ description: 'leak' }).expect(401);
    await request(app).post(`/api/tools/${toolId}/rent`).send({}).expect(401);
    await request(app).post('/api/jobs').send({ title: 'x' }).expect(401);
  });

  test('AI status is public but hides internals', async () => {
    const res = await request(app).get('/api/ai/status').expect(200);
    expect(Object.keys(res.body)).toEqual(['online']);
  });

  test('site stats', async () => {
    const res = await request(app).get('/api/meta/stats').expect(200);
    expect(res.body).toMatchObject({ technicians: 1, tools: 1 });
    expect(res.body).toHaveProperty('averageRating');
    expect(res.body).toHaveProperty('cities', 1);
  });
});
