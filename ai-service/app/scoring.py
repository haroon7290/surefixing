"""Explainable technician scoring.

Each candidate gets eight normalised components (0–1), a weighted sum
becomes ``matchPercent`` (0–100) and ``score`` (0–5), and the strongest
components are turned into human-readable ``reasons``. Cautions (few
reviews, over budget, unavailable…) go into ``notes``.

Two weight profiles:
* recommend – ranking every technician for a described problem
* bid       – ranking the quotes on one job (adds a price component)

Urgent requests boost responsiveness/availability weights. The backend has
an identical JS port (backend/src/services/scoring.js) used when this
service is offline — keep the two in sync.
"""

from typing import Any, Dict, List, Optional

from .text import tokenize
from .training_data import CATEGORY_LABELS

RECOMMEND_WEIGHTS = {
    "skill": 0.30,
    "rating": 0.22,
    "reliability": 0.13,
    "responsiveness": 0.08,
    "experience": 0.09,
    "proximity": 0.08,
    "availability": 0.05,
    "verified": 0.05,
}

BID_WEIGHTS = {
    "skill": 0.18,
    "rating": 0.24,
    "reliability": 0.14,
    "responsiveness": 0.08,
    "experience": 0.08,
    "price": 0.18,
    "proximity": 0.05,
    "verified": 0.05,
}

URGENCY_BOOST = {"high": 1.5, "emergency": 2.0}
RATING_PRIOR_MEAN = 3.5
RATING_PRIOR_WEIGHT = 3

SKILL_ALIASES = {
    "plumber": "plumbing", "electrician": "electrical", "electric": "electrical", "carpenter": "carpentry",
    "woodwork": "carpentry", "painter": "painting", "ac": "hvac", "air_conditioning": "hvac", "heating": "hvac",
    "cooling": "hvac", "appliances": "appliance", "appliance_repair": "appliance", "cleaner": "cleaning",
    "tiling": "masonry", "tile": "masonry", "mason": "masonry", "roof": "roofing", "pest": "pest_control",
    "pest_control": "pest_control", "locks": "locksmith", "handyman": "general",
}


def norm_skill(s: Any) -> str:
    k = "_".join(str(s or "").lower().strip().replace("-", " ").split())
    return SKILL_ALIASES.get(k, k)


def _num(v: Any, default: float = 0.0) -> float:
    try:
        x = float(v)
    except (TypeError, ValueError):
        return default
    return x if x == x else default  # NaN guard


def _sentence_case(label: str) -> str:
    """"Plumbing" → "plumbing", but keep acronyms: "AC & heating"."""
    if len(label) > 1 and label[1].isupper():
        return label
    return label[:1].lower() + label[1:]


def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def components(t: Dict[str, Any], ctx: Dict[str, Any], mode: str) -> Dict[str, float]:
    category = norm_skill(ctx.get("category")) if ctx.get("category") else ""
    skills = [norm_skill(s) for s in (t.get("skills") or [])]

    if category and category != "general":
        skill = 1.0 if category in skills else 0.0
    else:
        skill = 0.8 if "general" in skills else 0.5
    keywords = set(ctx.get("keywords") or [])
    if keywords and skill < 1:
        profile = set(tokenize(" ".join(map(str, t.get("skills") or [])) + f" {t.get('headline') or ''} {t.get('bio') or ''}"))
        overlap = len(keywords & profile)
        skill = max(skill, min(0.6, overlap / min(len(keywords), 5) * 0.6))

    n = _num(t.get("ratingCount"))
    r = _num(t.get("rating"))
    bayes = (r * n + RATING_PRIOR_MEAN * RATING_PRIOR_WEIGHT) / (n + RATING_PRIOR_WEIGHT)

    assigned = _num(t.get("jobsAssigned"))
    completed = _num(t.get("jobsCompleted"))
    reliability = _clamp01((min(completed, assigned or completed) + 2 * 0.8) / (max(assigned, completed) + 2))

    minutes = _num(t.get("avgResponseMinutes"), 60.0)
    if minutes <= 0:
        minutes = 60.0
    experience = 0.6 * min(1.0, completed / 40) + 0.4 * min(1.0, _num(t.get("experienceYears")) / 10)

    proximity = 0.5
    if ctx.get("city"):
        a = str(ctx["city"]).strip().lower()
        b = str(t.get("city") or "").strip().lower()
        proximity = 0.4 if not b else (1.0 if a == b else 0.1)

    c = {
        "skill": _clamp01(skill),
        "rating": _clamp01(bayes / 5),
        "reliability": reliability,
        "responsiveness": _clamp01(1 / (1 + minutes / 60)),
        "experience": _clamp01(experience),
        "proximity": proximity,
        "availability": 0.15 if t.get("isAvailable") is False else 1.0,
        "verified": 1.0 if (t.get("kycStatus") == "approved" or t.get("verified") is True) else 0.0,
    }

    if mode == "bid":
        amount = _num(t.get("amount"))
        min_amount = _num(ctx.get("minAmount")) or amount
        rel = _clamp01(min_amount / amount) if amount > 0 else 1.0
        budget = _num(ctx.get("budget"))
        if budget > 0:
            fit = 1.0 if amount <= budget else _clamp01(1 - (amount - budget) / budget)
        else:
            fit = rel
        c["price"] = 0.5 * rel + 0.5 * fit
    return c


def weights_for(mode: str, urgency: Optional[str]) -> Dict[str, float]:
    base = dict(BID_WEIGHTS if mode == "bid" else RECOMMEND_WEIGHTS)
    boost = URGENCY_BOOST.get(urgency or "")
    if boost:
        for k in ("responsiveness", "availability"):
            if k in base:
                base[k] *= boost
        total = sum(base.values())
        base = {k: v / total for k, v in base.items()}
    return base


def explain(t: Dict[str, Any], c: Dict[str, float], w: Dict[str, float], ctx: Dict[str, Any], mode: str):
    reasons: List[tuple] = []
    notes: List[str] = []

    def add(key: str, text: str) -> None:
        reasons.append((w.get(key, 0) * c.get(key, 0), text))

    category = norm_skill(ctx.get("category")) if ctx.get("category") else ""
    if c["skill"] >= 0.99 and category and category != "general":
        add("skill", f"Specialises in {_sentence_case(CATEGORY_LABELS.get(category, category))}")
    elif c["skill"] >= 0.3 and ctx.get("keywords"):
        add("skill", "Skills match your request")

    n = int(_num(t.get("ratingCount")))
    rating = _num(t.get("rating"))
    if n > 0 and rating >= 4:
        add("rating", f"Rated {rating:.1f}★ by {n} client{'' if n == 1 else 's'}")
    if n == 0:
        notes.append("New on SureFix — no reviews yet")

    assigned = int(_num(t.get("jobsAssigned")))
    completed = int(_num(t.get("jobsCompleted")))
    if assigned >= 3 and completed / assigned >= 0.85:
        add("reliability", f"Completed {min(completed, assigned)} of {assigned} hired jobs")

    minutes = _num(t.get("avgResponseMinutes"), 60.0) or 60.0
    if minutes <= 30:
        add("responsiveness", f"Usually responds in ~{max(1, round(minutes))} min")

    years = _num(t.get("experienceYears"))
    if years >= 3:
        add("experience", f"{int(years)}+ years of experience")
    elif completed >= 20:
        add("experience", f"{completed} jobs completed")

    if c["proximity"] == 1.0:
        add("proximity", f"Based in {t.get('city')}")
    elif c["proximity"] == 0.1 and t.get("city"):
        notes.append(f"Based in {t.get('city')} (outside your city)")

    if c["verified"] == 1.0:
        add("verified", "ID verified")
    if t.get("isAvailable") is False:
        notes.append("Currently unavailable")

    if mode == "bid":
        amount = _num(t.get("amount"))
        budget = _num(ctx.get("budget"))
        if ctx.get("bidCount", 0) > 1 and 0 < amount <= _num(ctx.get("minAmount")):
            add("price", "Lowest bid")
        elif budget > 0 and amount <= budget:
            add("price", "Within your budget")
        if budget > 0 and amount > budget:
            notes.append(f"{round((amount - budget) / budget * 100)}% over your budget")

    reasons.sort(key=lambda x: -x[0])
    return [text for _, text in reasons[:4]], notes


def score_one(t: Dict[str, Any], ctx: Optional[Dict[str, Any]] = None, mode: str = "recommend") -> Dict[str, Any]:
    ctx = ctx or {}
    c = components(t, ctx, mode)
    w = weights_for(mode, ctx.get("urgency"))
    total = _clamp01(sum(w[k] * c.get(k, 0) for k in w))
    reasons, notes = explain(t, c, w, ctx, mode)
    return {
        "score": round(total * 5, 2),
        "matchPercent": round(total * 100),
        "breakdown": {k: round(c.get(k, 0), 3) for k in w},
        "reasons": reasons,
        "notes": notes,
    }


def rank_list(items: List[Dict[str, Any]], ctx: Dict[str, Any], mode: str) -> List[Dict[str, Any]]:
    out = [{**t, **score_one(t, ctx, mode)} for t in items]
    out.sort(key=lambda x: (-x["score"], -_num(x.get("rating"))))
    return out


def rank_bids(technicians: List[Dict[str, Any]], ctx: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    ctx = dict(ctx or {})
    amounts = [a for a in (_num(t.get("amount")) for t in technicians) if a > 0]
    ctx["category"] = ctx.get("category") or ctx.get("jobCategory") or ""
    ctx["keywords"] = ctx.get("keywords") or tokenize(ctx.get("description") or "")
    ctx["minAmount"] = min(amounts) if amounts else 0
    ctx["bidCount"] = len(technicians)
    return rank_list(technicians, ctx, "bid")


def recommend(technicians: List[Dict[str, Any]], ctx: Dict[str, Any], analysis: Optional[Dict[str, Any]] = None):
    full = dict(ctx)
    full["category"] = ctx.get("category") or (analysis or {}).get("category") or ""
    full["urgency"] = ctx.get("urgency") or (analysis or {}).get("urgency") or "normal"
    full["keywords"] = tokenize(ctx.get("description") or "")
    return rank_list(technicians, full, "recommend")
