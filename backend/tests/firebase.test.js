// Firebase sign-in, with Firebase itself faked: an ID token here is
// "test-token|<uid>|<email>|<verified>".
jest.mock('../src/utils/firebase', () => ({
  enabled: jest.fn(() => true),
  canManage: jest.fn(() => false),
  syncUsers: jest.fn(async () => ({ imported: 0, linked: 0, failed: 0 })),
  deleteUser: jest.fn(async () => {}),
  checkPassword: jest.fn(async () => undefined),
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
  test('a new Firebase account becomes a SureFix account with the chosen role', async () => {
    const first = await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'no') }).expect(404);
    expect(first.body.code).toBe('needs_profile');

    const res = await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'no'), profile: { name: 'New Person', role: 'technician', city: 'Lahore' } }).expect(201);
    expect(res.body.user).toMatchObject({ email: 'new1@test.com', role: 'technician', city: 'Lahore' });
    expect(res.body.token).toBeTruthy();

    // Next time the same Firebase account just signs in.
    const again = await exchange({ idToken: tok('uid-new-1', 'new1@test.com', 'no') }).expect(200);
    expect(again.body.user.id).toBe(res.body.user.id);
    await request(app).get('/api/users/me').set('Authorization', `Bearer ${again.body.token}`).expect(200);
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
    firebase.checkPassword.mockResolvedValueOnce('uid-old-app'); // Firebase says: right password
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
