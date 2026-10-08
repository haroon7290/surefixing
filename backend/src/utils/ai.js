const fetch = require('node-fetch');

const AI_URL = process.env.AI_SERVICE_URL || 'http://localhost:5001';

// Local fallback used when the Python AI service isn't reachable. Weights
// chosen to mirror the production ranker: rating > completionRate > skill
// match > speed > experience.
function localScore(t) {
  return (
    (t.rating || 0) * 0.40 +
    (t.completionRate || 0) * 5 * 0.25 +
    (t.skillMatch || 0) * 5 * 0.15 +
    (t.responseSpeed || 0) * 5 * 0.10 +
    Math.min(1, (t.jobsCompleted || 0) / 50) * 5 * 0.10
  );
}

async function rankTechnicians(technicians, context = {}) {
  try {
    const res = await fetch(`${AI_URL}/rank`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ technicians, jobCategory: context.jobCategory || '' })
    });
    if (!res.ok) throw new Error(`AI service responded ${res.status}`);
    const data = await res.json();
    return data.ranked;
  } catch (err) {
    console.warn('AI service unavailable, falling back to local scoring:', err.message);
    return technicians
      .map((t) => ({ ...t, score: localScore(t) }))
      .sort((a, b) => b.score - a.score);
  }
}

module.exports = { rankTechnicians };
