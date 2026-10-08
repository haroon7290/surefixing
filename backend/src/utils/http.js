// Small HTTP helpers shared by the route handlers.

class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    if (details) this.details = details;
  }
}

const badRequest = (msg, details) => new HttpError(400, msg, details);
const forbidden = (msg = 'Not allowed') => new HttpError(403, msg);
const notFound = (msg = 'Not found') => new HttpError(404, msg);
const conflict = (msg) => new HttpError(409, msg);

function escapeRegex(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Reads ?page=&limit= and returns mongoose-ready skip/limit. Responses stay
// plain arrays (backwards compatible); the total goes in X-Total-Count.
function paginate(req, { defaultLimit = 50, maxLimit = 100 } = {}) {
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(maxLimit, Math.max(1, parseInt(req.query.limit, 10) || defaultLimit));
  return { page, limit, skip: (page - 1) * limit };
}

function setTotal(res, total) {
  res.set('X-Total-Count', String(total));
}

function sameId(a, b) {
  if (!a || !b) return false;
  return String(a._id || a) === String(b._id || b);
}

module.exports = { HttpError, badRequest, forbidden, notFound, conflict, escapeRegex, paginate, setTotal, sameId };
