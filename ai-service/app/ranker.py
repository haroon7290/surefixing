"""Technician ranking algorithm.

Input: list of technician candidates. Each has these fields (all optional,
default to 0):
    rating              float  0-5
    ratingCount         int
    jobsCompleted       int
    completionRate      float  0-1
    responseSpeed       float  0-1 (higher = faster)
    amount              float  bid amount (lower is better)

Returns the same list annotated with a ``score`` field (0-5), sorted
descending. The scoring is a weighted sum of normalized components. Swap
this function for a trained model once you have labeled data.
"""

from typing import List, Dict, Any

WEIGHTS = {
    "rating": 0.40,
    "completion": 0.25,
    "skill": 0.15,
    "response": 0.10,
    "experience": 0.10,
}


def _confidence(rating_count: int) -> float:
    """Damp the rating when there are few reviews."""
    return min(1.0, rating_count / 10.0) if rating_count else 0.3


def score_one(t: Dict[str, Any], job_category: str = "") -> float:
    rating = float(t.get("rating") or 0)
    rating_count = int(t.get("ratingCount") or 0)
    completion = float(t.get("completionRate") or 0)
    response = float(t.get("responseSpeed") or 0)
    jobs_done = int(t.get("jobsCompleted") or 0)

    # Skill match: prefer caller-provided flag, else compute from skills list.
    if "skillMatch" in t and t["skillMatch"] is not None:
        skill_norm = max(0.0, min(1.0, float(t["skillMatch"])))
    elif job_category:
        skills = [str(s).lower() for s in (t.get("skills") or [])]
        skill_norm = 1.0 if job_category.lower() in skills else 0.0
    else:
        skill_norm = 0.0

    rating_conf = _confidence(rating_count)
    rating_norm = (rating / 5.0) * rating_conf        # 0-1
    completion_norm = max(0.0, min(1.0, completion))  # 0-1
    response_norm = max(0.0, min(1.0, response))      # 0-1
    experience_norm = min(1.0, jobs_done / 50.0)      # 0-1

    raw = (
        WEIGHTS["rating"] * rating_norm
        + WEIGHTS["completion"] * completion_norm
        + WEIGHTS["skill"] * skill_norm
        + WEIGHTS["response"] * response_norm
        + WEIGHTS["experience"] * experience_norm
    )
    return round(raw * 5.0, 2)   # back to a 0-5 scale for display


def rank(technicians: List[Dict[str, Any]], job_category: str = "") -> List[Dict[str, Any]]:
    scored = []
    for t in technicians:
        entry = dict(t)
        entry["score"] = score_one(t, job_category)
        scored.append(entry)
    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored
