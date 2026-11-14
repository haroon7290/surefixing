// "Near me" search shared by the technician directory, the tool market and
// the technicians' job market.
//
//   with a radius:  MongoDB $geoNear on the 2dsphere index — only results
//                   within that many km, nearest first (or by `sort`).
//   without one:    everything that matches, each with its distance when it
//                   has a location; nearest first puts unknown ones last.
//
// Results are { doc, km } pairs: callers decide what to send, so nobody's
// coordinates leave the server — only the rounded distance does.
const { point, latLng, distanceKm, round1 } = require('../utils/geo');

const MAX_SCAN = 500;
const ready = new Map();

// $geoNear needs the index to exist (fresh databases build it on start-up).
function ensureIndexes(Model) {
  if (!ready.has(Model)) ready.set(Model, Model.init());
  return ready.get(Model);
}

// Within its own travel radius (technicians): distance ≤ serviceRadiusKm.
const coversMe = (doc, km) => km != null && km <= (doc.serviceRadiusKm || 15);

async function nearbySearch(Model, { filter = {}, near, radiusKm, sort, byDistance = true, covers = false, skip = 0, limit = 50 }) {
  if (radiusKm) {
    await ensureIndexes(Model);
    const pipeline = [
      { $geoNear: { near: point(near.lat, near.lng), key: 'geo', distanceField: 'distanceM', spherical: true, maxDistance: radiusKm * 1000, query: filter } }
    ];
    if (covers) pipeline.push({ $match: { $expr: { $lte: ['$distanceM', { $multiply: [{ $ifNull: ['$serviceRadiusKm', 15] }, 1000] }] } } });
    if (!byDistance && sort) pipeline.push({ $sort: sort });
    pipeline.push({ $facet: { items: [{ $skip: skip }, { $limit: limit }], total: [{ $count: 'n' }] } });
    const [res] = await Model.aggregate(pipeline);
    return {
      items: res.items.map((raw) => ({ doc: Model.hydrate(raw), km: round1(raw.distanceM / 1000) })),
      total: res.total[0]?.n || 0
    };
  }

  const docs = await Model.find(filter).sort(sort || { createdAt: -1 }).limit(MAX_SCAN);
  let rows = docs.map((doc) => ({ doc, km: round1(distanceKm(near, latLng(doc.geo))) }));
  if (covers) rows = rows.filter((r) => coversMe(r.doc, r.km));
  if (byDistance) rows.sort((a, b) => (a.km ?? Infinity) - (b.km ?? Infinity));
  return { items: rows.slice(skip, skip + limit), total: rows.length };
}

// Reads ?lat=&lng=&radius=&sort= into search options. `fallback` is a
// { lat, lng } to use when the request doesn't give one (e.g. the user's own
// saved location). Returns null when there is no location to search from.
function readNearby(query, fallback) {
  const lat = Number(query.lat);
  const lng = Number(query.lng);
  const given = query.lat !== undefined && query.lng !== undefined && query.lat !== '' && query.lng !== '';
  const near = given && Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 ? { lat, lng } : fallback || null;
  if (!near) return null;
  const radius = Number(query.radius);
  return {
    near,
    radiusKm: Number.isFinite(radius) && radius > 0 ? Math.min(radius, 500) : null,
    byDistance: !query.sort || query.sort === 'distance',
    covers: query.covers === '1'
  };
}

module.exports = { nearbySearch, readNearby, ensureIndexes };
