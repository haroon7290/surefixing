// Builds the Express app. Kept separate from server.js so tests can mount
// it with supertest without opening a port or a socket server.
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');

const config = require('./config');
const { uploadDir } = require('./middleware/upload');
const { notFoundHandler, errorHandler } = require('./middleware/error');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const jobRoutes = require('./routes/jobs');
const toolRoutes = require('./routes/tools');
const rentalRoutes = require('./routes/rentals');
const messageRoutes = require('./routes/messages');
const kycRoutes = require('./routes/kyc');
const adminRoutes = require('./routes/admin');
const reviewRoutes = require('./routes/reviews');
const reportRoutes = require('./routes/reports');
const aiRoutes = require('./routes/ai');
const metaRoutes = require('./routes/meta');

function createApp() {
  const app = express();
  app.set('trust proxy', 1);

  app.use(
    helmet({
      // Uploaded images are loaded cross-origin by the Flutter web build.
      crossOriginResourcePolicy: { policy: 'cross-origin' }
    })
  );
  app.use(
    cors({
      origin: config.corsOrigins.includes('*') ? '*' : config.corsOrigins,
      exposedHeaders: ['X-Total-Count']
    })
  );
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  if (!config.isTest) app.use(morgan('dev'));

  if (!config.isTest) {
    app.use(
      '/api',
      rateLimit({ windowMs: config.rateLimit.windowMs, limit: config.rateLimit.max, standardHeaders: 'draft-7', legacyHeaders: false })
    );
    app.use(
      ['/api/auth/login', '/api/auth/register'],
      rateLimit({
        windowMs: config.rateLimit.windowMs,
        limit: config.rateLimit.authMax,
        standardHeaders: 'draft-7',
        legacyHeaders: false,
        message: { error: 'Too many attempts. Please wait a few minutes and try again.' }
      })
    );
  }

  app.use('/uploads', express.static(uploadDir, { maxAge: '7d' }));

  app.get('/', (_req, res) => res.json({ ok: true, service: 'surefix-backend', version: '2.0.0' }));
  app.get('/api/health', (_req, res) =>
    res.json({ ok: true, db: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected', uptime: process.uptime() })
  );

  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/jobs', jobRoutes);
  app.use('/api/tools', toolRoutes);
  app.use('/api/rentals', rentalRoutes);
  app.use('/api/messages', messageRoutes);
  app.use('/api/kyc', kycRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/reviews', reviewRoutes);
  app.use('/api/reports', reportRoutes);
  app.use('/api/ai', aiRoutes);
  app.use('/api/meta', metaRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
