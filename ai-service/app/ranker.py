"""Backwards-compatible entry points (v1 API).

The scoring model now lives in ``app/scoring.py`` and the text model in
``app/classifier.py``. These wrappers keep older imports working.
"""

from typing import Any, Dict, List

from .scoring import rank_bids, score_one as _score_one


def score_one(t: Dict[str, Any], job_category: str = "") -> float:
    """0–5 score for one technician (recommendation weights)."""
    return _score_one(t, {"category": job_category}, "recommend")["score"]


def rank(technicians: List[Dict[str, Any]], job_category: str = "") -> List[Dict[str, Any]]:
    """Rank bids for a job; each item gains score/matchPercent/reasons."""
    return rank_bids(technicians, {"jobCategory": job_category})
