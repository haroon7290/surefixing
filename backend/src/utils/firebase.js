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

// Firebase Authentication REST API with the project's public web API key,
// for routes where the app doesn't talk to Firebase itself (older app
// versions using /api/auth/login and /register).
function canUseRest() {
  return enabled() && Boolean(config.firebase.webApiKey);
}

async function rest(method, body) {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${config.firebase.webApiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error?.message || `Firebase ${method} failed`);
    err.firebaseCode = String(data.error?.message || '').split(' ')[0];
    throw err;
  }
  return data;
}

// Checks an email + password. Resolves to { uid, idToken, verified }, or
// null when they don't match; undefined when this server can't check.
async function checkPassword(email, password) {
  if (!canUseRest()) return undefined;
  let signedIn;
  try {
    signedIn = await rest('signInWithPassword', { email, password, returnSecureToken: true });
  } catch (err) {
    if (['INVALID_LOGIN_CREDENTIALS', 'INVALID_PASSWORD', 'EMAIL_NOT_FOUND', 'USER_DISABLED', 'INVALID_EMAIL'].includes(err.firebaseCode)) return null;
    throw err;
  }
  const looked = await rest('lookup', { idToken: signedIn.idToken });
  return { uid: signedIn.localId, idToken: signedIn.idToken, verified: Boolean(looked.users?.[0]?.emailVerified) };
}

// Creates a Firebase account and emails it a verification link.
// Resolves to the uid; throws with firebaseCode 'EMAIL_EXISTS' if taken.
async function signUpAndVerify(email, password, name) {
  const created = await rest('signUp', { email, password, returnSecureToken: true });
  if (name) await rest('update', { idToken: created.idToken, displayName: name, returnSecureToken: false }).catch(() => {});
  await rest('sendOobCode', { requestType: 'VERIFY_EMAIL', idToken: created.idToken });
  return created.localId;
}

// Emails the verification link again (needs the account's password).
async function resendVerification(email, password) {
  const signedIn = await checkPassword(email, password);
  if (!signedIn) return false;
  if (!signedIn.verified) await rest('sendOobCode', { requestType: 'VERIFY_EMAIL', idToken: signedIn.idToken });
  return true;
}

// Emails Firebase's "choose a new password" link.
async function sendPasswordReset(email) {
  await rest('sendOobCode', { requestType: 'PASSWORD_RESET', email });
}

async function deleteUser(uid) {
  if (!uid || !enabled() || !canManage()) return;
  try {
    await auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') console.error('Firebase delete failed:', err.message);
  }
}

module.exports = { enabled, canManage, canUseRest, verify, syncUsers, checkPassword, signUpAndVerify, resendVerification, sendPasswordReset, deleteUser };
