const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body } = require('express-validator');
const config = require('../config');
const User = require('../models/User');
const mailer = require('../services/mailer');
const firebase = require('../utils/firebase');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { badRequest, HttpError } = require('../utils/http');

const router = express.Router();
const MAX_RESET_ATTEMPTS = 5;

function signToken(user) {
  return jwt.sign({ id: user._id, role: user.role }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

const emailField = () => body('email').trim().isEmail().withMessage('Enter a valid email address').toLowerCase();
const passwordField = (name, label) => body(name).isLength({ min: 6, max: 128 }).withMessage(`${label} must be at least 6 characters`);

router.post(
  '/register',
  [
    body('name').trim().isLength({ min: 2, max: 80 }).withMessage('Name must be at least 2 characters'),
    emailField(),
    passwordField('password', 'Password'),
    body('role').isIn(['client', 'technician', 'supplier', 'admin']).withMessage('Choose a valid role'),
    body('phone').optional({ values: 'falsy' }).trim().isLength({ max: 30 }),
    body('city').optional({ values: 'falsy' }).trim().isLength({ max: 60 })
  ],
  validate,
  async (req, res) => {
    const { name, email, password, role, phone, city } = req.body;
    if (role === 'admin') return res.status(403).json({ error: 'Admin accounts are provisioned separately' });
    if (await User.exists({ email })) return res.status(409).json({ error: 'An account with this email already exists' });
    // The email must be confirmed before the account can sign in: with
    // Firebase by a link Firebase emails, otherwise by a 6-digit code.
    if (firebase.canUseRest()) {
      let uid;
      try {
        uid = await firebase.signUpAndVerify(email, password, name);
      } catch (err) {
        if (err.firebaseCode === 'EMAIL_EXISTS') return res.status(409).json({ error: 'An account with this email already exists' });
        if (err.firebaseCode === 'WEAK_PASSWORD') throw badRequest('Choose a stronger password (at least 6 characters)');
        throw err;
      }
      await User.create({ name, email, password, role, phone, city: city || '', firebaseUid: uid, emailVerified: false });
      return res.status(202).json({ verify: 'link', email });
    }
    const user = await User.create({ name, email, password, role, phone, city: city || '', emailVerified: false });
    res.status(202).json({ verify: 'code', email, ...(await sendVerifyCode(user)) });
  }
);

// A 6-digit code to confirm the email (servers without Firebase).
async function sendVerifyCode(user) {
  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  user.verifyCodeHash = await bcrypt.hash(code, 8);
  user.verifyCodeExpires = new Date(Date.now() + config.resetCodeMinutes * 60 * 1000);
  user.verifyAttempts = 0;
  await user.save();
  await mailer.send({
    to: user.email,
    subject: 'Confirm your SureFix email',
    text: `Hi ${user.name},\n\nYour SureFix verification code is ${code}. It expires in ${config.resetCodeMinutes} minutes.\n\nIf you didn't sign up, you can ignore this email.`
  });
  const answer = { minutes: config.resetCodeMinutes, emailed: mailer.emailEnabled() };
  if (!mailer.emailEnabled() && !config.isProd) answer.devCode = code;
  return answer;
}

const unverified = (email, method) => ({
  error:
    method === 'link'
      ? `Confirm your email first: open the link we sent to ${email}, then log in.`
      : `Confirm your email first: enter the code we sent to ${email}.`,
  code: 'email_unverified',
  details: { method, email }
});

// Step 2 without Firebase: the code from the email.
router.post(
  '/verify-email',
  [emailField(), body('code').trim().matches(/^\d{6}$/).withMessage('Enter the 6-digit code')],
  validate,
  async (req, res) => {
    const invalid = badRequest('That code is wrong or has expired. Ask for a new one.');
    const user = await User.findOne({ email: req.body.email });
    if (!user) throw invalid;
    if (user.emailVerified) return res.json({ token: signToken(user), user: user.toPrivateJSON() });
    if (!user.verifyCodeHash || !user.verifyCodeExpires || user.verifyCodeExpires < new Date()) throw invalid;
    if (user.verifyAttempts >= MAX_RESET_ATTEMPTS) throw badRequest('Too many wrong attempts. Ask for a new code.');
    if (!(await bcrypt.compare(req.body.code, user.verifyCodeHash))) {
      user.verifyAttempts += 1;
      await user.save();
      throw invalid;
    }
    user.emailVerified = true;
    user.verifyCodeHash = '';
    user.verifyCodeExpires = null;
    user.verifyAttempts = 0;
    await user.save();
    if (user.status === 'suspended') return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'suspended' });
    res.json({ token: signToken(user), user: user.toPrivateJSON() });
  }
);

// Sends the link (Firebase accounts; needs the password) or a new code
// again. The answer doesn't reveal whether the email has an account.
router.post('/resend-verification', [emailField(), body('password').optional().isString()], validate, async (req, res) => {
  const user = await User.findOne({ email: req.body.email });
  if (!user || user.emailVerified) return res.json({ ok: true });
  if (user.firebaseUid && firebase.canUseRest()) {
    if (!req.body.password) throw badRequest('Enter your password to resend the link');
    const sent = await firebase.resendVerification(user.email, req.body.password).catch(() => false);
    if (!sent) return res.status(401).json({ error: 'Invalid email or password' });
    return res.json({ ok: true, method: 'link' });
  }
  res.json({ ok: true, method: 'code', ...(await sendVerifyCode(user)) });
});

// Firebase sign-in: the app signs in (or signs up) with Firebase and sends
// the ID token here; the answer is a normal SureFix session.
//   { idToken }                                   existing account
//   { idToken, profile: { name, role, phone?, city? } }   new account
// An existing account with the same email is linked only when Firebase has
// verified the email (accounts copied by the server are), so nobody can
// claim someone else's account by signing up with their address.
router.post(
  '/firebase',
  [
    body('idToken').isString().isLength({ min: 20 }).withMessage('Missing sign-in token'),
    body('profile.name').optional().trim().isLength({ min: 2, max: 80 }).withMessage('Name must be at least 2 characters'),
    body('profile.role').optional().isIn(['client', 'technician', 'supplier']).withMessage('Choose a valid role'),
    body('profile.phone').optional({ values: 'falsy' }).trim().isLength({ max: 30 }),
    body('profile.city').optional({ values: 'falsy' }).trim().isLength({ max: 60 })
  ],
  validate,
  async (req, res) => {
    if (!firebase.enabled()) return res.status(503).json({ error: 'Firebase sign-in is not set up on this server', code: 'firebase_off' });
    let claims;
    try {
      claims = await firebase.verify(req.body.idToken);
    } catch (_err) {
      return res.status(401).json({ error: 'Your sign-in could not be verified. Please try again.' });
    }
    const email = String(claims.email || '').toLowerCase();
    let user = await User.findOne({ firebaseUid: claims.uid });
    if (!user && email) {
      const existing = await User.findOne({ email });
      if (existing) {
        if (!claims.email_verified) {
          return res.status(409).json({ error: 'An account with this email already exists. Log in with its password instead.', code: 'email_taken' });
        }
        existing.firebaseUid = claims.uid;
        await existing.save();
        user = existing;
      }
    }
    if (!user) {
      const profile = req.body.profile;
      if (!profile?.name || !profile?.role) {
        return res.status(404).json({ error: 'Finish creating your SureFix account', code: 'needs_profile' });
      }
      if (!email) throw badRequest('Your account has no email address');
      user = await User.create({
        name: profile.name,
        email,
        // Never used: Firebase checks the password.
        password: crypto.randomBytes(24).toString('hex'),
        role: profile.role,
        phone: profile.phone || '',
        city: profile.city || '',
        firebaseUid: claims.uid,
        emailVerified: Boolean(claims.email_verified)
      });
      if (!claims.email_verified) return res.status(403).json(unverified(email, 'link'));
      return res.status(201).json({ token: signToken(user), user: user.toPrivateJSON() });
    }
    // Signing in needs a confirmed email (Firebase emails the link).
    if (!claims.email_verified) return res.status(403).json(unverified(email, 'link'));
    if (!user.emailVerified) {
      user.emailVerified = true;
      await user.save();
    }
    if (user.status === 'suspended') {
      return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'suspended' });
    }
    res.json({ token: signToken(user), user: user.toPrivateJSON() });
  }
);

router.post(
  '/login',
  [emailField(), body('password').isLength({ min: 1 }).withMessage('Password is required')],
  validate,
  async (req, res) => {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    // Accounts in Firebase: their password (and any reset) lives there, so
    // the copy here may be out of date. Check it with Firebase instead.
    if (user && user.firebaseUid && firebase.enabled()) {
      let uid;
      try {
        uid = await firebase.checkPassword(email, password);
      } catch (_err) {
        return res.status(503).json({ error: "Couldn't check your password right now. Please try again." });
      }
      if (uid === undefined) return res.status(409).json({ error: 'Please update SureFix to sign in.', code: 'use_firebase' });
      if (!uid || uid.uid !== user.firebaseUid) return res.status(401).json({ error: 'Invalid email or password' });
      if (!uid.verified) return res.status(403).json(unverified(email, 'link'));
      if (!user.emailVerified) {
        user.emailVerified = true;
        await user.save();
      }
      if (user.status === 'suspended') {
        return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'suspended' });
      }
      return res.json({ token: signToken(user), user: user.toPrivateJSON() });
    }
    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    if (!user.emailVerified) return res.status(403).json(unverified(email, 'code'));
    if (user.status === 'suspended') {
      return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'suspended' });
    }
    res.json({ token: signToken(user), user: user.toPrivateJSON() });
  }
);

router.post(
  '/change-password',
  authRequired,
  [body('currentPassword').isLength({ min: 1 }).withMessage('Current password is required'), passwordField('newPassword', 'New password')],
  validate,
  async (req, res) => {
    if (!(await req.user.matchPassword(req.body.currentPassword))) throw badRequest('Current password is incorrect');
    req.user.password = req.body.newPassword;
    await req.user.save();
    res.json({ ok: true });
  }
);

// ------------------------------------------------------- password reset

// Step 1: ask for a 6-digit code. The answer is the same whether or not the
// email has an account, so it can't be used to find out who is registered.
// With SMTP configured the code is emailed; otherwise it is printed in the
// backend console and — outside production — returned as `devCode` so the
// flow can be demonstrated without an email server.
router.post('/forgot-password', [emailField()], validate, async (req, res) => {
  const user = await User.findOne({ email: req.body.email, status: { $ne: 'suspended' } });
  // Passwords live in Firebase when the server can reach it: Firebase emails
  // a reset link (the same answer whether or not the account exists).
  if (firebase.canUseRest() && (!user || user.firebaseUid)) {
    if (user) {
      try {
        await firebase.sendPasswordReset(user.email);
      } catch (err) {
        if (err.firebaseCode === 'TOO_MANY_ATTEMPTS_TRY_LATER') throw new HttpError(429, 'Too many attempts. Please wait a few minutes and try again.');
        if (err.firebaseCode !== 'EMAIL_NOT_FOUND') throw err;
      }
    }
    return res.json({ ok: true, method: 'link' });
  }
  const answer = { ok: true, method: 'code', minutes: config.resetCodeMinutes, emailed: mailer.emailEnabled() };
  if (!user) return res.json(answer);

  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  user.resetCodeHash = await bcrypt.hash(code, 8);
  user.resetCodeExpires = new Date(Date.now() + config.resetCodeMinutes * 60 * 1000);
  user.resetAttempts = 0;
  await user.save();

  await mailer.send({
    to: user.email,
    subject: 'Your SureFix password reset code',
    text: `Hi ${user.name},\n\nYour SureFix reset code is ${code}. It expires in ${config.resetCodeMinutes} minutes.\n\nIf you didn't ask for this, you can ignore this email.`
  });
  if (!mailer.emailEnabled() && !config.isProd) answer.devCode = code;
  res.json(answer);
});

// Step 2: prove you have the code and set a new password.
router.post(
  '/reset-password',
  [emailField(), body('code').trim().matches(/^\d{6}$/).withMessage('Enter the 6-digit code'), passwordField('newPassword', 'New password')],
  validate,
  async (req, res) => {
    const invalid = badRequest('That code is wrong or has expired. Request a new one.');
    const user = await User.findOne({ email: req.body.email });
    if (!user || !user.resetCodeHash || !user.resetCodeExpires || user.resetCodeExpires < new Date()) throw invalid;
    if (user.resetAttempts >= MAX_RESET_ATTEMPTS) throw badRequest('Too many wrong attempts. Request a new code.');

    if (!(await bcrypt.compare(req.body.code, user.resetCodeHash))) {
      user.resetAttempts += 1;
      await user.save();
      throw invalid;
    }
    user.password = req.body.newPassword;
    user.resetCodeHash = '';
    user.resetCodeExpires = null;
    user.resetAttempts = 0;
    await user.save();
    if (user.status === 'suspended') return res.json({ ok: true });
    res.json({ ok: true, token: signToken(user), user: user.toPrivateJSON() });
  }
);

module.exports = router;
