const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');

const router = express.Router();

function signToken(user) {
  return jwt.sign(
    { id: user._id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

router.post(
  '/register',
  [
    body('name').trim().isLength({ min: 2 }),
    body('email').isEmail(),
    body('password').isLength({ min: 6 }),
    body('role').isIn(User.ROLES)
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    try {
      const { name, email, password, role, phone } = req.body;
      if (role === 'admin') return res.status(403).json({ error: 'Admin accounts are provisioned separately' });
      const existing = await User.findOne({ email });
      if (existing) return res.status(409).json({ error: 'Email already registered' });
      const user = await User.create({ name, email, password, role, phone });
      const token = signToken(user);
      res.status(201).json({ token, user: user.toPublicJSON() });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
);

router.post(
  '/login',
  [body('email').isEmail(), body('password').isLength({ min: 1 })],
  async (req, res) => {
    try {
      const { email, password } = req.body;
      const user = await User.findOne({ email });
      if (!user) return res.status(401).json({ error: 'Invalid credentials' });
      const ok = await user.matchPassword(password);
      if (!ok) return res.status(401).json({ error: 'Invalid credentials' });
      const token = signToken(user);
      res.json({ token, user: user.toPublicJSON() });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
);

module.exports = router;
