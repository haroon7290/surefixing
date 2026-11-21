// Firebase Authentication: Google handles passwords, sign-in and reset
// emails; SureFix keeps its own users and JWT sessions.
//
//   FIREBASE_PROJECT_ID        enough to verify sign-ins (public keys)
//   FIREBASE_SERVICE_ACCOUNT   service-account JSON (raw or base64): also
//                              lets the server copy existing accounts into
//                              Firebase and delete them there
//
// The app signs in with Firebase and exchanges the ID token for a SureFix
// session at POST /api/auth/firebase.
const config = require('../config');

let app = null;

function enabled() {
  return Boolean(config.firebase.projectId);
}

function canManage() {
  return Boolean(config.firebase.serviceAccount);
}

function firebaseApp() {
  if (app) return app;
  const { initializeApp, cert, getApps } = require('firebase-admin/app');
  const existing = getApps().find((a) => a.name === 'surefix');
  if (existing) return (app = existing);
  const options = { projectId: config.firebase.projectId };
  if (canManage()) options.credential = cert(config.firebase.serviceAccount);
  app = initializeApp(options, 'surefix');
  return app;
}

function auth() {
  const { getAuth } = require('firebase-admin/auth');
  return getAuth(firebaseApp());
}

// Checks an ID token from the app; resolves to its claims (uid, email,
// email_verified, name).
async function verify(idToken) {
  return auth().verifyIdToken(String(idToken || ''));
}

// Copies users who aren't in Firebase yet, keeping their passwords: the
// bcrypt hashes are imported as they are, so people sign in with the same
// password as before. Returns { imported, linked, failed }.
async function syncUsers(User, users) {
  const result = { imported: 0, linked: 0, failed: 0 };
  if (!enabled() || !canManage()) return result;
  const pending = users || (await User.find({ $or: [{ firebaseUid: '' }, { firebaseUid: null }, { firebaseUid: { $exists: false } }] }).select('+password'));
  for (let i = 0; i < pending.length; i += 1000) {
    const batch = pending.slice(i, i + 1000);
    const records = batch.map((u) => ({
      uid: String(u._id),
      email: u.email,
      emailVerified: true,
      displayName: u.name,
      passwordHash: Buffer.from(u.password || '')
    }));
    const res = await auth().importUsers(records, { hash: { algorithm: 'BCRYPT' } });
    const failed = new Map(res.errors.map((e) => [e.index, e.error]));
    for (const [index, u] of batch.entries()) {
      const error = failed.get(index);
      if (!error) {
        u.firebaseUid = String(u._id);
        result.imported += 1;
      } else {
        // Already in Firebase (e.g. the same project serves the live site
        // and a local copy): link to that account.
        try {
          u.firebaseUid = (await auth().getUserByEmail(u.email)).uid;
          result.linked += 1;
        } catch (_err) {
          result.failed += 1;
          console.error(`Firebase sync failed for ${u.email}: ${error.message || error}`);
          continue;
        }
      }
      await User.updateOne({ _id: u._id }, { $set: { firebaseUid: u.firebaseUid } });
    }
  }
  return result;
}

// Checks an email + password with Firebase (for app versions that still use
// POST /api/auth/login). Resolves to the Firebase uid, or null if wrong.
async function checkPassword(email, password) {
  if (!enabled() || !config.firebase.webApiKey) return undefined; // can't check here
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${config.firebase.webApiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: false })
  });
  if (!res.ok) return null;
  return (await res.json()).localId || null;
}

async function deleteUser(uid) {
  if (!uid || !enabled() || !canManage()) return;
  try {
    await auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') console.error('Firebase delete failed:', err.message);
  }
}

module.exports = { enabled, canManage, verify, syncUsers, checkPassword, deleteUser };
