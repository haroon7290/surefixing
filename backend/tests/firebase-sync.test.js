// Copying existing accounts into Firebase, against a fake firebase-admin.
const mockImported = [];
const mockAuth = {
  importUsers: jest.fn(async (records, options) => {
    mockImported.push({ records, options });
    // The second record already exists in Firebase (e.g. created by the live site).
    return { successCount: records.length - 1, failureCount: 1, errors: [{ index: 1, error: { code: 'auth/email-already-exists', message: 'exists' } }] };
  }),
  getUserByEmail: jest.fn(async (email) => ({ uid: `existing-${email}` }))
};
jest.mock('firebase-admin/app', () => ({ initializeApp: jest.fn(() => ({ name: 'surefix' })), cert: jest.fn((x) => x), getApps: jest.fn(() => []) }));
jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn(() => mockAuth) }));

const { connect, disconnect, clearDb } = require('./helpers');
const User = require('../src/models/User');
const config = require('../src/config');

beforeAll(connect);
afterAll(disconnect);

test('existing accounts are copied with their bcrypt password hashes, already-present ones linked', async () => {
  await clearDb();
  config.firebase.projectId = 'surefix-test';
  config.firebase.serviceAccount = { project_id: 'surefix-test', client_email: 'x@y', private_key: 'k' };
  const firebase = require('../src/utils/firebase');

  const a = await User.create({ name: 'Alpha', email: 'alpha@test.com', password: 'password123', role: 'client' });
  const b = await User.create({ name: 'Beta', email: 'beta@test.com', password: 'password123', role: 'technician' });
  await User.create({ name: 'Gamma', email: 'gamma@test.com', password: 'password123', role: 'client', firebaseUid: 'already' });

  const result = await firebase.syncUsers(User);
  expect(result).toEqual({ imported: 1, linked: 1, failed: 0 });

  const { records, options } = mockImported[0];
  expect(options).toEqual({ hash: { algorithm: 'BCRYPT' } });
  expect(records.map((r) => r.email).sort()).toEqual(['alpha@test.com', 'beta@test.com']); // Gamma is already linked
  const alpha = records.find((r) => r.email === 'alpha@test.com');
  const stored = await User.findById(a._id);
  expect(alpha.passwordHash.toString()).toBe(stored.password); // the same bcrypt hash: same password works
  expect(alpha.passwordHash.toString()).toMatch(/^\$2[aby]\$/);
  expect(alpha).toMatchObject({ uid: String(a._id), emailVerified: true, displayName: 'Alpha' });

  // records[0] was imported under its own id; records[1] already existed and was linked.
  const ids = Object.fromEntries((await User.find()).map((u) => [u.email, u.firebaseUid]));
  expect(ids[records[0].email]).toBe(records[0].uid);
  expect(ids[records[1].email]).toBe(`existing-${records[1].email}`);
  expect([String(a._id), String(b._id)]).toContain(records[0].uid);
  expect(ids['gamma@test.com']).toBe('already');

  config.firebase.projectId = '';
  config.firebase.serviceAccount = null;
});
