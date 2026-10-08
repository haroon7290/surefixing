// Runs before each test file (before any app module is required), so the
// config module picks up test settings.
const path = require('path');
const os = require('os');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';
// Point the AI client at a closed port so tests exercise the in-process
// fallback deterministically (the Python service has its own tests).
process.env.AI_SERVICE_URL = 'http://127.0.0.1:9';
process.env.UPLOAD_DIR = path.join(os.tmpdir(), 'surefix-test-uploads');

// Each test file gets its own throwaway database on the local MongoDB
// (override the server with MONGO_URL_TEST, e.g. in CI).
const base = process.env.MONGO_URL_TEST || 'mongodb://127.0.0.1:27017';
const worker = process.env.JEST_WORKER_ID || '0';
process.env.MONGO_URI = `${base.replace(/\/$/, '')}/surefix_test_${worker}_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
