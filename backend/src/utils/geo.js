// Small geography helpers. Points are stored as GeoJSON ({ type: 'Point',
// coordinates: [lng, lat] }) so MongoDB's 2dsphere index can search them.
const mongoose = require('mongoose');
const { AREAS } = require('../config/areas');

const pointSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['Point'], required: true, default: 'Point' },
    coordinates: { type: [Number], required: true } // [lng, lat]
  },
  { _id: false }
);

const validLat = (v) => Number.isFinite(v) && v >= -90 && v <= 90;
const validLng = (v) => Number.isFinite(v) && v >= -180 && v <= 180;

function point(lat, lng) {
  return { type: 'Point', coordinates: [Number(lng), Number(lat)] };
}

// { lat, lng } from a stored point (or null).
function latLng(geo) {
  if (!geo || !Array.isArray(geo.coordinates) || geo.coordinates.length !== 2) return null;
  return { lat: geo.coordinates[1], lng: geo.coordinates[0] };
}

// Reads ?lat=&lng= (or body fields). Returns null when absent; throws a
// readable error message string via the `invalid` flag when malformed.
function readLatLng(src) {
  if (src == null || src.lat === undefined || src.lat === '' || src.lng === undefined || src.lng === '') return null;
  const lat = Number(src.lat);
  const lng = Number(src.lng);
  if (!validLat(lat) || !validLng(lng)) return { invalid: true };
  return { lat, lng };
}

// Great-circle distance in kilometres.
function distanceKm(a, b) {
  if (!a || !b) return null;
  const R = 6371;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

const round1 = (km) => (km == null ? null : Math.round(km * 10) / 10);

// The closest known neighbourhood, if one is within `maxKm`.
function nearestArea(lat, lng, maxKm = 4) {
  let best = null;
  for (const a of AREAS) {
    const d = distanceKm({ lat, lng }, a);
    if (!best || d < best.km) best = { ...a, km: d };
  }
  return best && best.km <= maxKm ? best : null;
}

module.exports = { pointSchema, point, latLng, readLatLng, distanceKm, round1, nearestArea, validLat, validLng };
