const { app, request, connect, disconnect, makeUser } = require('./helpers');
const User = require('../src/models/User');

beforeAll(connect);
afterAll(disconnect);

const png = Buffer.from('89504e470d0a1a0a0000000d4948445200000001000000010806000000', 'hex');

describe('password reset', () => {
  test('code flow: request, wrong code, right code, old password stops working', async () => {
    const user = await makeUser('client');
    const asked = await request(app).post('/api/auth/forgot-password').send({ email: user.email });
    expect(asked.status).toBe(200);
    // No SMTP in tests, so the code comes back for the demo flow.
    expect(asked.body.devCode).toMatch(/^\d{6}$/);
    expect(asked.body.emailed).toBe(false);

    const wrong = asked.body.devCode === '000000' ? '111111' : '000000';
    await request(app).post('/api/auth/reset-password').send({ email: user.email, code: wrong, newPassword: 'newsecret1' }).expect(400);
    await request(app).post('/api/auth/reset-password').send({ email: user.email, code: asked.body.devCode, newPassword: '123' }).expect(400);

    const reset = await request(app).post('/api/auth/reset-password').send({ email: user.email, code: asked.body.devCode, newPassword: 'newsecret1' });
    expect(reset.status).toBe(200);
    expect(reset.body.token).toBeTruthy();
    await request(app).post('/api/auth/login').send({ email: user.email, password: user.password }).expect(401);
    await request(app).post('/api/auth/login').send({ email: user.email, password: 'newsecret1' }).expect(200);
    // A code works once.
    await request(app).post('/api/auth/reset-password').send({ email: user.email, code: asked.body.devCode, newPassword: 'another12' }).expect(400);
  });

  test('unknown emails get the same answer; codes expire and lock after 5 wrong tries', async () => {
    const ghost = await request(app).post('/api/auth/forgot-password').send({ email: 'nobody@example.com' });
    expect(ghost.status).toBe(200);
    expect(ghost.body.devCode).toBeUndefined();

    const user = await makeUser('technician');
    const asked = await request(app).post('/api/auth/forgot-password').send({ email: user.email });
    const wrong = asked.body.devCode === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) {
      await request(app).post('/api/auth/reset-password').send({ email: user.email, code: wrong, newPassword: 'newsecret1' }).expect(400);
    }
    const locked = await request(app).post('/api/auth/reset-password').send({ email: user.email, code: asked.body.devCode, newPassword: 'newsecret1' });
    expect(locked.status).toBe(400);
    expect(locked.body.error).toMatch(/too many/i);

    const again = await request(app).post('/api/auth/forgot-password').send({ email: user.email });
    await User.updateOne({ email: user.email }, { $set: { resetCodeExpires: new Date(Date.now() - 1000) } });
    await request(app).post('/api/auth/reset-password').send({ email: user.email, code: again.body.devCode, newPassword: 'newsecret1' }).expect(400);
  });
});

describe('favourites and portfolio', () => {
  let client;
  let tech;
  let supplier;
  let tool;

  beforeAll(async () => {
    client = await makeUser('client');
    tech = await makeUser('technician', { profile: { skills: ['plumbing'] } });
    supplier = await makeUser('supplier');
    tool = (await supplier.api('post', '/api/tools').send({ name: 'Ladder', rentPricePerDay: 300 })).body;
  });

  test('save and un-save technicians and tools', async () => {
    await client.api('post', '/api/users/me/favorites').send({ type: 'car', id: tech.id }).expect(400);
    await client.api('post', '/api/users/me/favorites').send({ type: 'technician', id: supplier.id }).expect(404);

    expect((await client.api('post', '/api/users/me/favorites').send({ type: 'technician', id: tech.id })).body.saved).toBe(true);
    expect((await client.api('post', '/api/users/me/favorites').send({ type: 'tool', id: tool._id })).body.saved).toBe(true);
    // Saving twice keeps one copy.
    await client.api('post', '/api/users/me/favorites').send({ type: 'tool', id: tool._id, saved: true }).expect(200);

    const list = await client.api('get', '/api/users/me/favorites');
    expect(list.body.technicians.map((t) => t.id)).toEqual([tech.id]);
    expect(list.body.tools.map((t) => t._id)).toEqual([tool._id]);
    expect(list.body.technicians[0].email).toBeUndefined();
    expect((await client.api('get', '/api/users/me')).body.favoriteTools).toEqual([tool._id]);

    expect((await client.api('post', '/api/users/me/favorites').send({ type: 'technician', id: tech.id })).body.saved).toBe(false);
    expect((await client.api('get', '/api/users/me/favorites')).body.technicians).toHaveLength(0);
  });

  test('technicians manage a portfolio shown on their public profile', async () => {
    await client.api('post', '/api/users/me/portfolio').attach('images', png, 'a.png').expect(403);
    await tech.api('post', '/api/users/me/portfolio').expect(400);

    const added = await tech.api('post', '/api/users/me/portfolio').attach('images', png, 'a.png').attach('images', png, 'b.png');
    expect(added.status).toBe(201);
    expect(added.body.portfolio).toHaveLength(2);

    const profile = await request(app).get(`/api/users/${tech.id}`);
    expect(profile.body.portfolio).toHaveLength(2);
    expect(profile.body.walletBalance).toBeUndefined(); // private fields stay private

    const removed = await tech.api('delete', `/api/users/me/portfolio/${added.body.portfolio[0]}`);
    expect(removed.body.portfolio).toEqual([added.body.portfolio[1]]);
    await tech.api('delete', '/api/users/me/portfolio/nope.png').expect(404);

    // The portfolio is capped.
    await User.updateOne({ _id: tech.id }, { $set: { portfolio: Array.from({ length: 8 }, (_, i) => `p${i}.png`) } });
    const full = await tech.api('post', '/api/users/me/portfolio').attach('images', png, 'c.png');
    expect(full.status).toBe(400);
    expect(full.body.error).toMatch(/up to 8/);
  });
});
