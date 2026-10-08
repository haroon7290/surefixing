// In-process fallback for the Python AI service (ai-service/app). Used when
// that service is unreachable so recommendations never break. It mirrors
// the Python scoring formula (weights, components, reasons) exactly; the
// text classifier is a simpler keyword model than the Python Naive Bayes.
// If you change weights here, change ai-service/app/scoring.py too.

const { SERVICE_CATEGORIES } = require('../config/catalog');

const CATEGORY_LABEL = Object.fromEntries(SERVICE_CATEGORIES.map((c) => [c.key, c.label]));

const RECOMMEND_WEIGHTS = {
  skill: 0.3,
  rating: 0.22,
  reliability: 0.13,
  responsiveness: 0.08,
  experience: 0.09,
  proximity: 0.08,
  availability: 0.05,
  verified: 0.05
};

const BID_WEIGHTS = {
  skill: 0.18,
  rating: 0.24,
  reliability: 0.14,
  responsiveness: 0.08,
  experience: 0.08,
  price: 0.18,
  proximity: 0.05,
  verified: 0.05
};

const URGENCY_BOOST = { high: 1.5, emergency: 2.0 };
const RATING_PRIOR_MEAN = 3.5;
const RATING_PRIOR_WEIGHT = 3;

// ---------------------------------------------------------------- text

const STOPWORDS = new Set(
  ('a an the and or but if of to in on at by for with from into over under is are was were be been ' +
    'being am i im me my we our you your it its this that these those there here very some any also ' +
    'just so too can could would should will shall may might must do does did done have has had not ' +
    'no need needs needed want wants please help someone somebody get got fix fixed fixing repair ' +
    'repaired repairing service work working come out up down again still what when where how which ' +
    'who why dont doesnt cant wont isnt about around one two three since than then them they their')
    .split(/\s+/)
);

function stem(word) {
  let w = word;
  if (w.length > 4 && w.endsWith('ies')) w = `${w.slice(0, -3)}y`;
  else if (w.length > 5 && w.endsWith('oes')) w = w.slice(0, -2);
  else if (w.length > 4 && /(ches|shes|sses|xes|zes)$/.test(w)) w = w.slice(0, -2);
  else if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) w = w.slice(0, -1);

  let stripped = false;
  if (w.length > 5 && w.endsWith('ing')) {
    w = w.slice(0, -3);
    stripped = true;
  } else if (w.length > 4 && w.endsWith('ed')) {
    w = w.slice(0, -2);
    stripped = true;
  } else if (w.length > 4 && w.endsWith('er')) {
    w = w.slice(0, -2);
    stripped = true;
  }
  if (stripped && w.length > 2 && w[w.length - 1] === w[w.length - 2] && !'lsz'.includes(w[w.length - 1])) {
    w = w.slice(0, -1);
  }
  return w;
}

function tokenize(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^a-z\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOPWORDS.has(t))
    .map(stem);
}

// Keyword lexicon per category. Multi-word phrases count double.
const LEXICON = {
  plumbing: ['leak', 'pipe', 'faucet', 'tap', 'sink', 'drain', 'clog', 'blocked', 'toilet', 'flush', 'shower',
    'geyser', 'valve', 'sewage', 'sewer', 'plumber', 'basin', 'water tank', 'water pump', 'drip', 'water pressure',
    'overflow', 'cistern', 'commode', 'bathroom', 'water heater', 'hot water'],
  electrical: ['wiring', 'wire', 'socket', 'switch', 'outlet', 'breaker', 'fuse', 'circuit', 'short circuit',
    'light', 'bulb', 'ceiling fan', 'fan', 'power', 'electricity', 'voltage', 'electrician', 'spark', 'shock',
    'ups', 'inverter', 'generator', 'meter', 'tripping', 'chandelier', 'led', 'electric', 'db box'],
  carpentry: ['wood', 'door', 'cabinet', 'cupboard', 'wardrobe', 'furniture', 'table', 'chair', 'shelf', 'drawer',
    'hinge', 'carpenter', 'bed', 'wooden', 'deck', 'window frame', 'door frame', 'laminate', 'plywood', 'kitchen cabinet'],
  painting: ['paint', 'wall paint', 'colour', 'color', 'primer', 'coat', 'painter', 'whitewash', 'distemper',
    'enamel', 'wallpaper', 'peeling', 'putty', 'texture', 'repaint', 'emulsion'],
  appliance: ['washing machine', 'fridge', 'refrigerator', 'freezer', 'oven', 'microwave', 'dishwasher', 'dryer',
    'stove', 'cooker', 'appliance', 'television', 'tv', 'iron', 'blender', 'water dispenser', 'vacuum', 'deep freezer'],
  hvac: ['ac', 'air conditioner', 'air conditioning', 'cooling', 'heating', 'heater', 'furnace', 'thermostat',
    'duct', 'vent', 'hvac', 'compressor', 'gas refill', 'split ac', 'chiller', 'ventilation', 'heat pump', 'not cooling'],
  cleaning: ['clean', 'cleaning', 'deep clean', 'carpet', 'sofa', 'mop', 'dust', 'sanitize', 'maid', 'tank cleaning',
    'grease', 'mold', 'mould', 'upholstery', 'pressure wash', 'disinfect', 'cleaner'],
  masonry: ['tile', 'tiling', 'brick', 'cement', 'concrete', 'plaster', 'crack', 'grout', 'marble', 'floor',
    'flooring', 'mason', 'stone', 'granite', 'foundation', 'boundary wall'],
  roofing: ['roof', 'roofing', 'gutter', 'shingle', 'waterproofing', 'seepage', 'terrace', 'skylight', 'chimney',
    'rain water', 'roof leak', 'ceiling leak', 'damp'],
  pest_control: ['pest', 'termite', 'cockroach', 'roach', 'ant', 'rat', 'mouse', 'mice', 'rodent', 'bed bug',
    'bug', 'mosquito', 'insect', 'fumigation', 'wasp', 'lizard', 'spray'],
  locksmith: ['lock', 'locked', 'key', 'locksmith', 'lockout', 'deadbolt', 'padlock', 'latch', 'door lock',
    'smart lock', 'locked out', 'safe'],
  general: ['install', 'mount', 'assemble', 'assembly', 'hang', 'curtain', 'rod', 'handyman', 'tv mount',
    'picture', 'odd job', 'small repair', 'general']
};

// Pre-stem the lexicon once so lookups match tokenize() output.
const STEMMED_LEXICON = Object.fromEntries(
  Object.entries(LEXICON).map(([cat, terms]) => [
    cat,
    terms.map((term) => {
      const parts = term.split(' ').map((p) => stem(p));
      return { parts, weight: parts.length > 1 ? 2 : 1 };
    })
  ])
);

const URGENCY_TERMS = {
  emergency: ['flood', 'burst', 'spark', 'smoke', 'fire', 'gas leak', 'gas smell', 'smell of gas', 'electrocut',
    'electric shock', 'short circuit', 'sewage overflow', 'emergency', 'dangerous', 'collapsed'],
  low: ['no rush', 'not urgent', 'whenever', 'next week', 'next month', 'flexible', 'sometime', 'when possible',
    'eventually', 'no hurry'],
  high: ['urgent', 'asap', 'as soon as possible', 'immediately', 'right now', 'today', 'tonight', 'leak',
    'no water', 'no power', 'no electricity', 'not working', 'stopped working', 'broken', 'locked out',
    'overflowing', 'no hot water', 'not cooling']
};

function detectUrgency(text) {
  const t = ` ${String(text || '').toLowerCase().replace(/[^a-z\s]/g, ' ').replace(/\s+/g, ' ')} `;
  const hits = (level) => URGENCY_TERMS[level].filter((term) => new RegExp(`\\b${term}`).test(t));
  for (const level of ['emergency', 'low', 'high']) {
    const found = hits(level);
    if (found.length) return { urgency: level, urgencyTerms: found };
  }
  return { urgency: 'normal', urgencyTerms: [] };
}

function analyze(text) {
  const tokens = tokenize(text);
  const scores = {};
  const matched = new Set();
  for (const [cat, terms] of Object.entries(STEMMED_LEXICON)) {
    let s = 0;
    for (const { parts, weight } of terms) {
      for (let i = 0; i + parts.length <= tokens.length; i += 1) {
        if (parts.every((p, k) => tokens[i + k] === p)) {
          s += weight;
          matched.add(parts.join(' '));
        }
      }
    }
    if (s > 0) scores[cat] = s;
  }
  const total = Object.values(scores).reduce((a, b) => a + b, 0);
  let categories = Object.entries(scores)
    .map(([category, s]) => ({ category, confidence: +(s / total).toFixed(3) }))
    .sort((a, b) => b.confidence - a.confidence);
  if (!categories.length) categories = [{ category: 'general', confidence: 0.3 }];
  // Damp confidence when the evidence is thin (one weak keyword).
  const top = categories[0];
  const evidence = Math.min(1, total / 3);
  const confidence = +(top.confidence * (0.5 + 0.5 * evidence)).toFixed(3);
  return {
    category: top.category,
    confidence,
    categories: categories.slice(0, 3),
    ...detectUrgency(text),
    keywords: [...matched].slice(0, 8),
    engine: 'fallback'
  };
}

// --------------------------------------------------------------- scoring

const SKILL_ALIASES = {
  plumber: 'plumbing', electrician: 'electrical', electric: 'electrical', carpenter: 'carpentry',
  woodwork: 'carpentry', painter: 'painting', ac: 'hvac', air_conditioning: 'hvac', heating: 'hvac',
  cooling: 'hvac', appliances: 'appliance', appliance_repair: 'appliance', cleaner: 'cleaning',
  tiling: 'masonry', tile: 'masonry', mason: 'masonry', roof: 'roofing', pest: 'pest_control',
  pest_control: 'pest_control', locks: 'locksmith', handyman: 'general'
};

function normSkill(s) {
  const k = String(s || '').toLowerCase().trim().replace(/[\s-]+/g, '_');
  return SKILL_ALIASES[k] || k;
}

// "Plumbing" → "plumbing", but keep acronyms: "AC & heating".
const sentenceCase = (label) => (label.length > 1 && label[1] === label[1].toUpperCase() && /[A-Z]/.test(label[1]) ? label : label.charAt(0).toLowerCase() + label.slice(1));

const clamp01 = (x) => Math.max(0, Math.min(1, Number.isFinite(x) ? x : 0));

function components(t, ctx, mode) {
  const category = ctx.category ? normSkill(ctx.category) : '';
  const skills = (t.skills || []).map(normSkill);

  // Skill: exact category specialisation, else keyword overlap with profile.
  let skill;
  if (category && category !== 'general') {
    skill = skills.includes(category) ? 1 : 0;
  } else {
    skill = skills.includes('general') ? 0.8 : 0.5;
  }
  const keywords = new Set(ctx.keywords || []);
  if (keywords.size && skill < 1) {
    const profile = new Set(tokenize(`${(t.skills || []).join(' ')} ${t.headline || ''} ${t.bio || ''}`));
    let overlap = 0;
    keywords.forEach((k) => { if (profile.has(k)) overlap += 1; });
    skill = Math.max(skill, Math.min(0.6, (overlap / Math.min(keywords.size, 5)) * 0.6));
  }

  const n = Number(t.ratingCount) || 0;
  const r = Number(t.rating) || 0;
  const bayes = (r * n + RATING_PRIOR_MEAN * RATING_PRIOR_WEIGHT) / (n + RATING_PRIOR_WEIGHT);

  const assigned = Number(t.jobsAssigned) || 0;
  const completed = Number(t.jobsCompleted) || 0;
  const reliability = clamp01((Math.min(completed, assigned || completed) + 2 * 0.8) / (Math.max(assigned, completed) + 2));

  const minutes = Number(t.avgResponseMinutes) > 0 ? Number(t.avgResponseMinutes) : 60;
  const experience = 0.6 * Math.min(1, completed / 40) + 0.4 * Math.min(1, (Number(t.experienceYears) || 0) / 10);

  let proximity = 0.5;
  if (ctx.city) {
    const a = String(ctx.city).trim().toLowerCase();
    const b = String(t.city || '').trim().toLowerCase();
    proximity = !b ? 0.4 : a === b ? 1 : 0.1;
  }

  const c = {
    skill: clamp01(skill),
    rating: clamp01(bayes / 5),
    reliability,
    responsiveness: clamp01(1 / (1 + minutes / 60)),
    experience: clamp01(experience),
    proximity,
    availability: t.isAvailable === false ? 0.15 : 1,
    verified: t.kycStatus === 'approved' || t.verified === true ? 1 : 0
  };

  if (mode === 'bid') {
    const amount = Number(t.amount) || 0;
    const minAmount = Number(ctx.minAmount) || amount;
    const rel = amount > 0 ? clamp01(minAmount / amount) : 1;
    const budget = Number(ctx.budget) || 0;
    const fit = budget > 0 ? (amount <= budget ? 1 : clamp01(1 - (amount - budget) / budget)) : rel;
    c.price = 0.5 * rel + 0.5 * fit;
  }
  return c;
}

function weightsFor(mode, urgency) {
  const base = { ...(mode === 'bid' ? BID_WEIGHTS : RECOMMEND_WEIGHTS) };
  const boost = URGENCY_BOOST[urgency];
  if (boost) {
    if (base.responsiveness) base.responsiveness *= boost;
    if (base.availability) base.availability *= boost;
    const sum = Object.values(base).reduce((a, b) => a + b, 0);
    Object.keys(base).forEach((k) => { base[k] /= sum; });
  }
  return base;
}

function explain(t, c, w, ctx, mode) {
  const reasons = [];
  const notes = [];
  const add = (key, text) => reasons.push({ weight: (w[key] || 0) * (c[key] || 0), text });
  const category = ctx.category ? normSkill(ctx.category) : '';

  if (c.skill >= 0.99 && category && category !== 'general') add('skill', `Specialises in ${sentenceCase(CATEGORY_LABEL[category] || category)}`);
  else if (c.skill >= 0.3 && (ctx.keywords || []).length) add('skill', 'Skills match your request');

  const n = Number(t.ratingCount) || 0;
  if (n > 0 && Number(t.rating) >= 4) add('rating', `Rated ${Number(t.rating).toFixed(1)}★ by ${n} client${n === 1 ? '' : 's'}`);
  if (n === 0) notes.push('New on SureFix — no reviews yet');

  const assigned = Number(t.jobsAssigned) || 0;
  const completed = Number(t.jobsCompleted) || 0;
  if (assigned >= 3 && completed / assigned >= 0.85) add('reliability', `Completed ${Math.min(completed, assigned)} of ${assigned} hired jobs`);

  const minutes = Number(t.avgResponseMinutes) || 60;
  if (minutes <= 30) add('responsiveness', `Usually responds in ~${Math.max(1, Math.round(minutes))} min`);

  const years = Number(t.experienceYears) || 0;
  if (years >= 3) add('experience', `${years}+ years of experience`);
  else if (completed >= 20) add('experience', `${completed} jobs completed`);

  if (c.proximity === 1) add('proximity', `Based in ${t.city}`);
  else if (c.proximity === 0.1 && t.city) notes.push(`Based in ${t.city} (outside your city)`);

  if (c.verified === 1) add('verified', 'ID verified');
  if (t.isAvailable === false) notes.push('Currently unavailable');

  if (mode === 'bid') {
    const amount = Number(t.amount) || 0;
    const budget = Number(ctx.budget) || 0;
    if (ctx.bidCount > 1 && amount > 0 && amount <= Number(ctx.minAmount)) add('price', 'Lowest bid');
    else if (budget > 0 && amount <= budget) add('price', 'Within your budget');
    if (budget > 0 && amount > budget) notes.push(`${Math.round(((amount - budget) / budget) * 100)}% over your budget`);
  }

  return {
    reasons: reasons.sort((a, b) => b.weight - a.weight).slice(0, 4).map((r) => r.text),
    notes
  };
}

function scoreOne(t, ctx = {}, mode = 'recommend') {
  const c = components(t, ctx, mode);
  const w = weightsFor(mode, ctx.urgency);
  let total = 0;
  const breakdown = {};
  Object.keys(w).forEach((k) => {
    breakdown[k] = +(c[k] || 0).toFixed(3);
    total += w[k] * (c[k] || 0);
  });
  total = clamp01(total);
  const { reasons, notes } = explain(t, c, w, ctx, mode);
  return {
    score: +(total * 5).toFixed(2),
    matchPercent: Math.round(total * 100),
    breakdown,
    reasons,
    notes
  };
}

function rankList(items, ctx, mode) {
  return items
    .map((t) => ({ ...t, ...scoreOne(t, ctx, mode) }))
    .sort((a, b) => b.score - a.score || (Number(b.rating) || 0) - (Number(a.rating) || 0));
}

function rankBids(technicians, ctx = {}) {
  const amounts = technicians.map((t) => Number(t.amount) || 0).filter((a) => a > 0);
  const full = {
    ...ctx,
    category: ctx.category || ctx.jobCategory || '',
    keywords: ctx.keywords || tokenize(ctx.description || ''),
    minAmount: amounts.length ? Math.min(...amounts) : 0,
    bidCount: technicians.length
  };
  return rankList(technicians, full, 'bid');
}

function recommend(technicians, ctx = {}) {
  const analysis = ctx.description ? analyze(ctx.description) : null;
  const full = {
    ...ctx,
    category: ctx.category || analysis?.category || '',
    urgency: ctx.urgency || analysis?.urgency || 'normal',
    keywords: tokenize(ctx.description || '')
  };
  return { analysis, ranked: rankList(technicians, full, 'recommend') };
}

module.exports = {
  analyze,
  detectUrgency,
  tokenize,
  stem,
  scoreOne,
  rankBids,
  recommend,
  RECOMMEND_WEIGHTS,
  BID_WEIGHTS
};
