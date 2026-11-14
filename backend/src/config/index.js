// Central place for environment-driven settings. Every value has a safe
// default so the backend starts with no .env at all (see .env.example).
require('dotenv').config();

const env = process.env.NODE_ENV || 'development';

const DEFAULT_SECRET = 'change_me_to_a_long_random_string';

const num = (value, fallback) => {
  const n = Number(value);
  return value !== undefined && value !== '' && Number.isFinite(n) ? n : fallback;
};

const config = {
  env,
  isTest: env === 'test',
  isProd: env === 'production',
  port: num(process.env.PORT, 4000),
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/surefix',
  jwtSecret: process.env.JWT_SECRET || DEFAULT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  aiServiceUrl: process.env.AI_SERVICE_URL || 'http://localhost:5001',
  aiTimeoutMs: num(process.env.AI_TIMEOUT_MS, 2500),
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  // Comma-separated list of allowed browser origins. "*" (default) allows
  // any origin, which is what the mobile app + local web builds need.
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  rateLimit: {
    windowMs: 15 * 60 * 1000,
    max: num(process.env.RATE_LIMIT_MAX, 1000),
    authMax: num(process.env.AUTH_RATE_LIMIT_MAX, 30)
  },

  // Marketplace rules.
  platformFeePercent: num(process.env.PLATFORM_FEE_PERCENT, 10),
  // After a technician marks a job done, the client has this long to confirm
  // before the technician may close it themselves.
  autoConfirmHours: num(process.env.AUTO_CONFIRM_HOURS, 72),
  // Wallet: money comes in by deposits to the company's accounts and goes
  // out by withdrawals, each checked and approved by an admin.
  wallet: {
    minDeposit: num(process.env.WALLET_MIN_DEPOSIT, 100),
    maxDeposit: num(process.env.WALLET_MAX_DEPOSIT, 500000),
    minWithdrawal: num(process.env.WALLET_MIN_WITHDRAWAL, 500),
    maxPendingDeposits: num(process.env.WALLET_MAX_PENDING_DEPOSITS, 5)
  },

  // Optional SMTP (e.g. smtps://user:pass@smtp.example.com). Without it,
  // password-reset codes are printed in this console instead of emailed.
  smtpUrl: process.env.SMTP_URL || '',
  mailFrom: process.env.MAIL_FROM || 'SureFix <no-reply@surefix.local>',
  resetCodeMinutes: num(process.env.RESET_CODE_MINUTES, 15)
};

if (config.isProd && config.jwtSecret === DEFAULT_SECRET) {
  throw new Error('JWT_SECRET must be set to a strong random value in production');
}

module.exports = config;
