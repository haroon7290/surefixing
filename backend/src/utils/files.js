const fs = require('fs');
const path = require('path');
const { uploadDir } = require('../middleware/upload');

// Deletes an uploaded image by its stored filename (best effort).
function removeUpload(name) {
  if (!name) return;
  fs.unlink(path.join(uploadDir, path.basename(String(name))), () => {});
}

module.exports = { removeUpload };
