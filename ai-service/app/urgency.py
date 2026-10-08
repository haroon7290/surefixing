"""Rule-based urgency detection.

Safety terms win (emergency), then explicit "no rush" style phrases (low —
checked before "high" because "not urgent" contains "urgent"), then time
pressure / outage words (high). Mirrors detectUrgency() in
backend/src/services/scoring.js.
"""

import re
from typing import Dict, List

from .text import normalise_phrase

URGENCY_TERMS: Dict[str, List[str]] = {
    "emergency": ["flood", "burst", "spark", "smoke", "fire", "gas leak", "gas smell", "smell of gas", "electrocut",
                  "electric shock", "short circuit", "sewage overflow", "emergency", "dangerous", "collapsed"],
    "low": ["no rush", "not urgent", "whenever", "next week", "next month", "flexible", "sometime", "when possible",
            "eventually", "no hurry"],
    "high": ["urgent", "asap", "as soon as possible", "immediately", "right now", "today", "tonight", "leak",
             "no water", "no power", "no electricity", "not working", "stopped working", "broken", "locked out",
             "overflowing", "no hot water", "not cooling"],
}

_PATTERNS = {level: [(t, re.compile(r"\b" + re.escape(t))) for t in terms] for level, terms in URGENCY_TERMS.items()}


def detect_urgency(text: str) -> dict:
    t = normalise_phrase(text)
    for level in ("emergency", "low", "high"):
        found = [term for term, rx in _PATTERNS[level] if rx.search(t)]
        if found:
            return {"urgency": level, "urgencyTerms": found}
    return {"urgency": "normal", "urgencyTerms": []}
