const jwt = require('jsonwebtoken');
const config = require('../config');
const User = require('../models/User');

async function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch (_err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
  const user = await User.findById(payload.id);
  if (!user) return res.status(401).json({ error: 'Invalid token user' });
  if (user.status === 'suspended') {
    return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'suspended' });
  }
  req.user = user;
  next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: `Requires role: ${roles.join(', ')}` });
    }
    next();
  };
}

module.exports = { authRequired, requireRole };
