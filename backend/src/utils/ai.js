// Client for the Python AI service, with a transparent in-process fallback
// (services/scoring.js) so ranking/recommendation keep working when the
// service is offline. Every result carries `engine` so the UI can say which
// one answered.
const config = require('../config');
const scoring = require('../services/scoring');

async function callAi(path, body, { method = 'POST' } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.aiTimeoutMs);
  try {
    const res = await fetch(`${config.aiServiceUrl}${path}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: method === 'GET' ? undefined : JSON.stringify(body),
      signal: controller.signal
    });
    if (!res.ok) throw new Error(`AI service responded ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

function warn(err) {
  if (!config.isTest) console.warn('AI service unavailable, using local fallback:', err.message);
}

async function analyzeText(text) {
  try {
    const data = await callAi('/analyze', { text });
    return { ...data, engine: 'ai-service' };
  } catch (err) {
    warn(err);
    return scoring.analyze(text);
  }
}

// Ranks the bids on one job. `technicians` are bid+technician rows.
async function rankTechnicians(technicians, context = {}) {
  try {
    const data = await callAi('/rank', {
      technicians,
      jobCategory: context.jobCategory || '',
      description: context.description || '',
      budget: context.budget || 0,
      city: context.city || '',
      urgency: context.urgency || 'normal'
    });
    return data.ranked.map((r) => ({ ...r, engine: 'ai-service' }));
  } catch (err) {
    warn(err);
    return scoring.rankBids(technicians, context).map((r) => ({ ...r, engine: 'fallback' }));
  }
}

// Ranks every candidate technician for a free-text problem description.
async function recommendTechnicians(technicians, context = {}) {
  try {
    const data = await callAi('/recommend', { ...context, technicians });
    return { analysis: data.analysis, ranked: data.ranked, engine: 'ai-service' };
  } catch (err) {
    warn(err);
    const { analysis, ranked } = scoring.recommend(technicians, context);
    return { analysis, ranked, engine: 'fallback' };
  }
}

async function status() {
  try {
    const data = await callAi('/health', null, { method: 'GET' });
    return { online: true, url: config.aiServiceUrl, ...data };
  } catch (err) {
    return { online: false, url: config.aiServiceUrl, error: err.message };
  }
}

module.exports = { analyzeText, rankTechnicians, recommendTechnicians, status };
