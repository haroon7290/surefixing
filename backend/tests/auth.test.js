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

  test('sign-up needs the emailed code before the first login; emails are case-insensitive', async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Case Test', email: 'Case.Test@Example.com', password: 'secret123', role: 'technician', city: 'Lahore' });
    expect(reg.status).toBe(202);
    expect(reg.body).toMatchObject({ verify: 'code', email: 'case.test@example.com' });
    expect(reg.body.token).toBeUndefined();
    expect(reg.body.devCode).toMatch(/^\d{6}$/);

    const blocked = await request(app).post('/api/auth/login').send({ email: 'CASE.test@example.com', password: 'secret123' });
    expect(blocked.status).toBe(403);
    expect(blocked.body).toMatchObject({ code: 'email_unverified', details: { method: 'code' } });

    const wrong = reg.body.devCode === '000000' ? '111111' : '000000';
    await request(app).post('/api/auth/verify-email').send({ email: 'case.test@example.com', code: wrong }).expect(400);
    const ok = await request(app).post('/api/auth/verify-email').send({ email: 'Case.Test@Example.com', code: reg.body.devCode }).expect(200);
    expect(ok.body.token).toBeTruthy();
    expect(ok.body.user).toMatchObject({ email: 'case.test@example.com', role: 'technician', city: 'Lahore', status: 'active' });
    expect(ok.body.user.password).toBeUndefined();

    const login = await request(app).post('/api/auth/login').send({ email: 'CASE.test@example.com', password: 'secret123' });
    expect(login.status).toBe(200);
    expect(login.body.user.email).toBe('case.test@example.com');
  });

  test('a new code can be sent; old accounts are already verified', async () => {
    const reg = await request(app).post('/api/auth/register').send({ name: 'Resend Me', email: 'resend@test.com', password: 'secret123', role: 'client' }).expect(202);
    const again = await request(app).post('/api/auth/resend-verification').send({ email: 'resend@test.com' }).expect(200);
    expect(again.body.method).toBe('code');
    expect(again.body.devCode).not.toBe(undefined);
    await request(app).post('/api/auth/verify-email').send({ email: 'resend@test.com', code: reg.body.devCode === again.body.devCode ? again.body.devCode : reg.body.devCode }).expect(again.body.devCode === reg.body.devCode ? 200 : 400);
    await request(app).post('/api/auth/verify-email').send({ email: 'resend@test.com', code: again.body.devCode }).expect(200);
    // Unknown emails get the same answer (no account fishing).
    expect((await request(app).post('/api/auth/resend-verification').send({ email: 'nobody@test.com' })).body).toEqual({ ok: true });
    // Accounts that existed before verification was added keep working.
    const legacy = await User.create({ name: 'Old Timer', email: 'old@test.com', password: 'secret123', role: 'client' });
    expect(legacy.emailVerified).toBe(true);
    await request(app).post('/api/auth/login').send({ email: 'old@test.com', password: 'secret123' }).expect(200);
  });

  test('duplicate email is rejected', async () => {
    const body = { name: 'Dup', email: 'dup@test.com', password: 'secret123', role: 'client' };
    await request(app).post('/api/auth/register').send(body).expect(202);
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
