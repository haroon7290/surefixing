// Central place for environment-driven settings. Every value has a safe
// default so an existing backend/.env from older versions keeps working.
require('dotenv').config();

const env = process.env.NODE_ENV || 'development';

const DEFAULT_SECRET = 'change_me_to_a_long_random_string';

const config = {
  env,
  isTest: env === 'test',
  isProd: env === 'production',
  port: Number(process.env.PORT) || 4000,
  // Database name stays "fixit" so data created by earlier versions is kept.
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/fixit',
  jwtSecret: process.env.JWT_SECRET || DEFAULT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  aiServiceUrl: process.env.AI_SERVICE_URL || 'http://localhost:5001',
  aiTimeoutMs: Number(process.env.AI_TIMEOUT_MS) || 2500,
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  // Comma-separated list of allowed browser origins. "*" (default) allows
  // any origin, which is what the mobile app + local web builds need.
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  rateLimit: {
    windowMs: 15 * 60 * 1000,
    max: Number(process.env.RATE_LIMIT_MAX) || 1000,
    authMax: Number(process.env.AUTH_RATE_LIMIT_MAX) || 30
  }
};

if (config.isProd && config.jwtSecret === DEFAULT_SECRET) {
  throw new Error('JWT_SECRET must be set to a strong random value in production');
}

module.exports = config;
