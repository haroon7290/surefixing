const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body } = require('express-validator');
const config = require('../config');
const User = require('../models/User');
const mailer = require('../services/mailer');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { badRequest } = require('../utils/http');

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
    const user = await User.create({ name, email, password, role, phone, city: city || '' });
    res.status(201).json({ token: signToken(user), user: user.toPrivateJSON() });
  }
);

router.post(
  '/login',
  [emailField(), body('password').isLength({ min: 1 }).withMessage('Password is required')],
  validate,
  async (req, res) => {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
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
  const answer = { ok: true, minutes: config.resetCodeMinutes, emailed: mailer.emailEnabled() };
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
