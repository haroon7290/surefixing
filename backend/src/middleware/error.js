const multer = require('multer');
const config = require('../config');

function notFoundHandler(req, res) {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.originalUrl}` });
}

// Express 5 forwards rejected promises from async handlers here, so routes
// can simply `throw` (or let mongoose throw) instead of try/catch blocks.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, _req, res, _next) {
  let status = err.status || err.statusCode || 500;
  let message = err.message || 'Server error';

  if (err.name === 'CastError') {
    status = 400;
    message = `Invalid ${err.path || 'id'}`;
  } else if (err.name === 'ValidationError') {
    status = 400;
    const first = Object.values(err.errors || {})[0];
    message = first ? first.message : 'Validation failed';
  } else if (err instanceof multer.MulterError) {
    status = 400;
    message = err.code === 'LIMIT_FILE_SIZE' ? 'Image too large (max 10 MB)' : err.message;
  } else if (err.type === 'entity.parse.failed') {
    status = 400;
    message = 'Malformed JSON body';
  } else if (err.code === 11000) {
    status = 409;
    message = 'Duplicate value';
  }

  if (status >= 500) {
    if (!config.isTest) console.error(err);
    if (config.isProd) message = 'Server error';
  }
  const body = { error: message };
  if (err.details) body.details = err.details;
  res.status(status).json(body);
}

module.exports = { notFoundHandler, errorHandler };
