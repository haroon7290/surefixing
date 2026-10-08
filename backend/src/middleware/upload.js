const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const config = require('../config');
const { badRequest } = require('../utils/http');

const uploadDir = path.resolve(config.uploadDir);
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif']);

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase() || '.jpg';
    cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
  }
});

// Only images are accepted anywhere in the API. Some mobile pickers send
// application/octet-stream, so the extension is accepted as a fallback.
function imageFilter(_req, file, cb) {
  const ext = path.extname(file.originalname || '').toLowerCase();
  if ((file.mimetype || '').startsWith('image/') || ALLOWED_EXT.has(ext)) return cb(null, true);
  cb(badRequest('Only image uploads are allowed'));
}

module.exports = multer({
  storage,
  fileFilter: imageFilter,
  limits: { fileSize: 10 * 1024 * 1024, files: 6 }
});
module.exports.uploadDir = uploadDir;
