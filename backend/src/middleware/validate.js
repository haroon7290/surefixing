const fs = require('fs');
const { validationResult } = require('express-validator');

// Removes files multer already wrote when the request is rejected, so
// failed submissions don't leave orphaned images in uploads/.
function discardUploads(req) {
  const files = [];
  if (req.file) files.push(req.file);
  if (Array.isArray(req.files)) files.push(...req.files);
  else if (req.files && typeof req.files === 'object') Object.values(req.files).forEach((arr) => files.push(...arr));
  files.forEach((f) => fs.unlink(f.path, () => {}));
}

// Runs after an express-validator chain. Responds 400 with a readable
// top-level `error` (what the app shows) plus the full `errors` array.
function validate(req, res, next) {
  const result = validationResult(req);
  if (result.isEmpty()) return next();
  discardUploads(req);
  const errors = result.array();
  const first = errors[0];
  const message = first.msg && first.msg !== 'Invalid value' ? first.msg : `Invalid ${first.path}`;
  return res.status(400).json({ error: message, errors });
}

module.exports = { validate, discardUploads };
