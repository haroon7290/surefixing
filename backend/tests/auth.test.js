const { app, request, connect, disconnect, makeUser } = require('./helpers');
const User = require('../src/models/User');

beforeAll(connect);
afterAll(disconnect);

describe('auth', () => {
  test('register validates input and returns a readable error', async () => {
    const res = await request(app).post('/api/auth/register').send({ name: 'x', email: 'nope', password: '1', role: 'client' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/at least 2 characters/);
    expect(res.body.errors.length).toBeGreaterThanOrEqual(3);
  });

  test('register + login round trip, emails are case-insensitive', async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Case Test', email: 'Case.Test@Example.com', password: 'secret123', role: 'technician', city: 'Lahore' });
    expect(reg.status).toBe(201);
    expect(reg.body.token).toBeTruthy();
    expect(reg.body.user).toMatchObject({ email: 'case.test@example.com', role: 'technician', city: 'Lahore', status: 'active' });
    expect(reg.body.user.password).toBeUndefined();

    const login = await request(app).post('/api/auth/login').send({ email: 'CASE.test@example.com', password: 'secret123' });
    expect(login.status).toBe(200);
    expect(login.body.user.email).toBe('case.test@example.com');
  });

  test('duplicate email is rejected', async () => {
    const body = { name: 'Dup', email: 'dup@test.com', password: 'secret123', role: 'client' };
    await request(app).post('/api/auth/register').send(body).expect(201);
    const res = await request(app).post('/api/auth/register').send(body);
    expect(res.status).toBe(409);
  });

  test('admin accounts cannot self-register', async () => {
    const res = await request(app).post('/api/auth/register').send({ name: 'Evil', email: 'evil@test.com', password: 'secret123', role: 'admin' });
    expect(res.status).toBe(403);
  });

  test('wrong password is rejected with a generic message', async () => {
    const u = await makeUser('client');
    const res = await request(app).post('/api/auth/login').send({ email: u.email, password: 'wrong-password' });
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('Invalid email or password');
  });

  test('suspended users cannot log in or use an existing token', async () => {
    const u = await makeUser('client');
    await User.updateOne({ email: u.email }, { $set: { status: 'suspended' } });
    const login = await request(app).post('/api/auth/login').send({ email: u.email, password: u.password });
    expect(login.status).toBe(403);
    const me = await u.api('get', '/api/users/me');
    expect(me.status).toBe(403);
    expect(me.body.code).toBe('suspended');
  });

  test('change password requires the current password', async () => {
    const u = await makeUser('client');
    const bad = await u.api('post', '/api/auth/change-password').send({ currentPassword: 'nope', newPassword: 'newsecret1' });
    expect(bad.status).toBe(400);
    await u.api('post', '/api/auth/change-password').send({ currentPassword: u.password, newPassword: 'newsecret1' }).expect(200);
    const login = await request(app).post('/api/auth/login').send({ email: u.email, password: 'newsecret1' });
    expect(login.status).toBe(200);
  });

  test('protected routes need a valid token', async () => {
    await request(app).get('/api/users/me').expect(401);
    await request(app).get('/api/users/me').set('Authorization', 'Bearer garbage').expect(401);
  });
});
