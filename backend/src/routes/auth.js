const express = require('express');
const jwt = require('jsonwebtoken');
const { body } = require('express-validator');
const config = require('../config');
const User = require('../models/User');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const router = express.Router();

function signToken(user) {
  return jwt.sign({ id: user._id, role: user.role }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

router.post(
  '/register',
  [
    body('name').trim().isLength({ min: 2, max: 80 }).withMessage('Name must be at least 2 characters'),
    body('email').trim().isEmail().withMessage('Enter a valid email address').toLowerCase(),
    body('password').isLength({ min: 6, max: 128 }).withMessage('Password must be at least 6 characters'),
    body('role').isIn(['client', 'technician', 'supplier', 'admin']).withMessage('Choose a valid role'),
    body('phone').optional({ values: 'falsy' }).trim().isLength({ max: 30 }),
    body('city').optional({ values: 'falsy' }).trim().isLength({ max: 60 })
  ],
  validate,
  async (req, res) => {
    const { name, email, password, role, phone, city } = req.body;
    if (role === 'admin') return res.status(403).json({ error: 'Admin accounts are provisioned separately' });
    const existing = await User.findOne({ email });
    if (existing) return res.status(409).json({ error: 'Email already registered' });
    const user = await User.create({ name, email, password, role, phone, city: city || '' });
    res.status(201).json({ token: signToken(user), user: user.toPublicJSON() });
  }
);

router.post(
  '/login',
  [
    body('email').trim().isEmail().withMessage('Enter a valid email address').toLowerCase(),
    body('password').isLength({ min: 1 }).withMessage('Password is required')
  ],
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
    res.json({ token: signToken(user), user: user.toPublicJSON() });
  }
);

router.post(
  '/change-password',
  authRequired,
  [
    body('currentPassword').isLength({ min: 1 }).withMessage('Current password is required'),
    body('newPassword').isLength({ min: 6, max: 128 }).withMessage('New password must be at least 6 characters')
  ],
  validate,
  async (req, res) => {
    const ok = await req.user.matchPassword(req.body.currentPassword);
    if (!ok) return res.status(400).json({ error: 'Current password is incorrect' });
    req.user.password = req.body.newPassword;
    await req.user.save();
    res.json({ ok: true });
  }
);

module.exports = router;
