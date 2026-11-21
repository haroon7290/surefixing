// Firebase sign-in, with Firebase itself faked: an ID token here is
// "test-token|<uid>|<email>|<verified>".
jest.mock('../src/utils/firebase', () => ({
  enabled: jest.fn(() => true),
  canManage: jest.fn(() => false),
  syncUsers: jest.fn(async () => ({ imported: 0, linked: 0, failed: 0 })),
  deleteUser: jest.fn(async () => {}),
  checkPassword: jest.fn(async () => undefined),
  canUseRest: jest.fn(() => false),
  signUpAndVerify: jest.fn(async () => 'uid-from-rest'),
  resendVerification: jest.fn(async () => true),
  verify: jest.fn(async (token) => {
    const [kind, uid, email, verified] = String(token).split('|');
    if (kind !== 'test-token') throw new Error('bad token');
    return { uid, email, email_verified: verified === 'yes' };
  })
}));

const { app, request, connect, disconnect, makeUser } = require('./helpers');
const firebase = require('../src/utils/firebase');
const User = require('../src/models/User');

beforeAll(connect);
afterAll(disconnect);

const tok = (uid, email, verified = 'yes') => `test-token|${uid}|${email}|${verified}`;
const exchange = (body) => request(app).post('/api/auth/firebase').send(body);

describe('Firebase sign-in', () => {
  test('a new Firebase account becomes a SureFix account, usable once the email is confirmed', async () => {
    const first = await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'no') }).expect(404);
    expect(first.body.code).toBe('needs_profile');

    // Created straight away, but no session until the email is confirmed.
    const created = await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'no'), profile: { name: 'New Person', role: 'technician', city: 'Lahore' } }).expect(403);
    expect(created.body).toMatchObject({ code: 'email_unverified', details: { method: 'link' } });
    expect(created.body.token).toBeUndefined();
    expect(await User.findOne({ email: 'new1@test.com' })).toMatchObject({ role: 'technician', city: 'Lahore', emailVerified: false });
    await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'no') }).expect(403);

    // After clicking the link the Firebase token says verified.
    const res = await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'yes') }).expect(200);
    expect(res.body.user).toMatchObject({ email: 'new1@test.com', role: 'technician', city: 'Lahore' });
    expect(res.body.token).toBeTruthy();
    expect((await User.findOne({ email: 'new1@test.com' })).emailVerified).toBe(true);
    await request(app).get('/api/users/me').set('Authorization', `Bearer ${res.body.token}`).expect(200);
  });

  test('sign-up on the password route (older apps): Firebase account + verification link, then login', async () => {
    firebase.canUseRest.mockReturnValue(true);
    const reg = await request(app).post('/api/auth/register').send({ name: 'Old App User', email: 'oldapp@test.com', password: 'secret123', role: 'client' }).expect(202);
    expect(reg.body).toEqual({ verify: 'link', email: 'oldapp@test.com' });
    expect(firebase.signUpAndVerify).toHaveBeenCalledWith('oldapp@test.com', 'secret123', 'Old App User');
    expect((await User.findOne({ email: 'oldapp@test.com' })).firebaseUid).toBe('uid-from-rest');

    firebase.checkPassword.mockResolvedValueOnce({ uid: 'uid-from-rest', verified: false });
    const blocked = await request(app).post('/api/auth/login').send({ email: 'oldapp@test.com', password: 'secret123' }).expect(403);
    expect(blocked.body.details.method).toBe('link');
    await request(app).post('/api/auth/resend-verification').send({ email: 'oldapp@test.com', password: 'secret123' }).expect(200);
    expect(firebase.resendVerification).toHaveBeenCalled();

    firebase.checkPassword.mockResolvedValueOnce({ uid: 'uid-from-rest', verified: true });
    await request(app).post('/api/auth/login').send({ email: 'oldapp@test.com', password: 'secret123' }).expect(200);
    firebase.canUseRest.mockReturnValue(false);
  });

  test('an existing account is linked by email only when Firebase verified the email', async () => {
    const old = await makeUser('client');
    const unverified = await exchange({ idToken: tok('uid-attacker', old.email, 'no'), profile: { name: 'Attacker', role: 'client' } }).expect(409);
    expect(unverified.body.code).toBe('email_taken');

    const linked = await exchange({ idToken: tok('uid-owner', old.email, 'yes') }).expect(200);
    expect(linked.body.user.id).toBe(old.id);
    expect((await User.findById(old.id)).firebaseUid).toBe('uid-owner');
  });

  test('once in Firebase, the old password route is closed for that account', async () => {
    const u = await makeUser('client');
    await exchange({ idToken: tok('uid-moved', u.email) }).expect(200);
    const res = await request(app).post('/api/auth/login').send({ email: u.email, password: u.password }).expect(409);
    expect(res.body.code).toBe('use_firebase');
  });

  test('older apps using the password route are checked against Firebase', async () => {
    const u = await makeUser('client');
    await exchange({ idToken: tok('uid-old-app', u.email) }).expect(200);
    firebase.checkPassword.mockResolvedValueOnce({ uid: 'uid-old-app', verified: true }); // Firebase says: right password
    const ok = await request(app).post('/api/auth/login').send({ email: u.email, password: 'new-password-from-reset' }).expect(200);
    expect(ok.body.user.id).toBe(u.id);
    firebase.checkPassword.mockResolvedValueOnce(null); // wrong password
    await request(app).post('/api/auth/login').send({ email: u.email, password: u.password }).expect(401);
  });

  test('suspended accounts and bad tokens are refused; admins cannot be created', async () => {
    const u = await makeUser('client');
    await exchange({ idToken: tok('uid-susp', u.email) }).expect(200);
    await User.updateOne({ _id: u.id }, { $set: { status: 'suspended' } });
    expect((await exchange({ idToken: tok('uid-susp', u.email) }).expect(403)).body.code).toBe('suspended');

    await exchange({ idToken: 'not-a-real-token-at-all' }).expect(401);
    await exchange({ idToken: tok('uid-x', 'x@test.com'), profile: { name: 'Sneaky', role: 'admin' } }).expect(400);
  });

  test('without Firebase on the server the endpoint says so and old login works', async () => {
    firebase.enabled.mockReturnValueOnce(false);
    expect((await exchange({ idToken: tok('uid-a', 'a@test.com') }).expect(503)).body.code).toBe('firebase_off');
    const u = await makeUser('client');
    firebase.enabled.mockReturnValue(false);
    await request(app).post('/api/auth/login').send({ email: u.email, password: u.password }).expect(200);
    firebase.enabled.mockReturnValue(true);
  });

  test('deleting a user removes their Firebase account', async () => {
    const admin = await makeUser('admin');
    const u = await makeUser('client');
    await exchange({ idToken: tok('uid-gone', u.email) }).expect(200);
    await admin.api('delete', `/api/admin/users/${u.id}`).expect(200);
    expect(firebase.deleteUser).toHaveBeenCalledWith('uid-gone');
  });
});
