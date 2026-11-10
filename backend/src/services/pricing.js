// Price guidance for a service category: "jobs like this usually cost X–Y".
// Learned from what completed jobs in that category actually cost; until a
// category has enough history, the baseline range from the catalog is used.
const Job = require('../models/Job');
const { SERVICE_CATEGORIES } = require('../config/catalog');

const MIN_SAMPLES = 5;
const MAX_SAMPLES = 200;
// Urgent work costs more: call-out at short notice.
const URGENCY_FACTOR = { low: 0.95, normal: 1, high: 1.15, emergency: 1.3 };

const BASELINE = Object.fromEntries(SERVICE_CATEGORIES.map((c) => [c.key, c.price]));

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = (sorted.length - 1) * p;
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
}

// Rounds to a tidy figure: nearest 50 below 2,000, nearest 100 above.
function tidy(n) {
  const step = n < 2000 ? 50 : 100;
  return Math.max(step, Math.round(n / step) * step);
}

async function estimate(category, urgency = 'normal') {
  const key = BASELINE[category] ? category : 'general';
  const factor = URGENCY_FACTOR[urgency] || 1;

  const jobs = await Job.find({ category: key, status: 'completed', agreedPrice: { $gt: 0 } })
    .sort({ completedAt: -1 })
    .limit(MAX_SAMPLES)
    .select('agreedPrice');
  const prices = jobs.map((j) => j.agreedPrice).sort((a, b) => a - b);

  let low;
  let high;
  let basis = 'baseline';
  if (prices.length >= MIN_SAMPLES) {
    low = percentile(prices, 0.25);
    high = percentile(prices, 0.75);
    basis = 'history';
  } else {
    [low, high] = BASELINE[key];
  }
  low = tidy(low * factor);
  high = Math.max(tidy(high * factor), low);
  return { category: key, urgency, low, high, typical: tidy((low + high) / 2), basis, samples: prices.length };
}

module.exports = { estimate, percentile, tidy };
