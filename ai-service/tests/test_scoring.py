import json
import shutil
import subprocess
from pathlib import Path

import pytest

from app import scoring
from app.text import tokenize

BASE = {"rating": 4.5, "ratingCount": 10, "jobsCompleted": 10, "jobsAssigned": 10, "avgResponseMinutes": 30, "city": "Lahore"}


def test_specialist_beats_generalist():
    ranked = scoring.recommend(
        [{**BASE, "technicianId": "a", "skills": ["painting"]}, {**BASE, "technicianId": "b", "skills": ["plumbing"]}],
        {"description": "leaking pipe under the sink", "city": "Lahore"},
        {"category": "plumbing", "urgency": "high"},
    )
    assert ranked[0]["technicianId"] == "b"
    assert "Specialises in plumbing" in ranked[0]["reasons"]
    assert 0 < ranked[0]["matchPercent"] <= 100
    assert ranked[0]["score"] == pytest.approx(ranked[0]["matchPercent"] / 20, abs=0.03)


def test_bayesian_rating_damps_few_reviews():
    one = scoring.score_one({**BASE, "rating": 5, "ratingCount": 1})
    many = scoring.score_one({**BASE, "rating": 4.8, "ratingCount": 40})
    assert many["breakdown"]["rating"] > one["breakdown"]["rating"]


def test_urgency_boosts_fast_responders():
    fast = {**BASE, "technicianId": "fast", "skills": ["plumbing"], "avgResponseMinutes": 5, "rating": 4.2}
    slow = {**BASE, "technicianId": "slow", "skills": ["plumbing"], "avgResponseMinutes": 240, "rating": 4.6}

    def gap(urgency):
        r = {x["technicianId"]: x["score"] for x in scoring.recommend([fast, slow], {"category": "plumbing", "urgency": urgency})}
        return r["fast"] - r["slow"]

    assert gap("emergency") > gap("low")


def test_weights_sum_to_one():
    for mode in ("recommend", "bid"):
        for urgency in (None, "high", "emergency"):
            assert sum(scoring.weights_for(mode, urgency).values()) == pytest.approx(1.0)


def test_bid_ranking_prices_and_notes():
    ranked = scoring.rank_bids(
        [{**BASE, "technicianId": "cheap", "skills": ["plumbing"], "amount": 1000},
         {**BASE, "technicianId": "pricey", "skills": ["plumbing"], "amount": 3000}],
        {"jobCategory": "plumbing", "budget": 2000},
    )
    assert [r["technicianId"] for r in ranked] == ["cheap", "pricey"]
    assert "Lowest bid" in ranked[0]["reasons"]
    assert "50% over your budget" in ranked[1]["notes"]


def test_notes_for_new_unavailable_or_distant_technicians():
    r = scoring.score_one({"ratingCount": 0, "isAvailable": False, "city": "Karachi"}, {"city": "Lahore"})
    assert "New on SureFix — no reviews yet" in r["notes"]
    assert "Currently unavailable" in r["notes"]
    assert any("outside your city" in n for n in r["notes"])


def test_skill_aliases_and_keyword_overlap():
    assert scoring.norm_skill("Pest Control") == "pest_control"
    assert scoring.norm_skill("electrician") == "electrical"
    r = scoring.score_one({"skills": [], "headline": "Fridge and washing machine repairs"},
                          {"category": "general", "keywords": tokenize("fridge washing")})
    assert r["breakdown"]["skill"] > 0.5


@pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")
def test_parity_with_backend_js_fallback():
    """The backend's offline fallback must rank exactly like this service."""
    techs = [
        {**BASE, "technicianId": "a", "skills": ["plumbing"], "amount": 2800, "kycStatus": "approved"},
        {**BASE, "technicianId": "b", "skills": ["painting"], "amount": 3500, "city": "Karachi", "ratingCount": 0},
        {**BASE, "technicianId": "c", "skills": ["plumbing", "general"], "amount": 3000, "avgResponseMinutes": 8,
         "experienceYears": 6, "isAvailable": False},
    ]
    ctx = {"jobCategory": "plumbing", "description": "leaking pipe under the sink", "budget": 3000,
           "city": "Lahore", "urgency": "high"}
    scoring_js = Path(__file__).resolve().parents[2] / "backend" / "src" / "services" / "scoring.js"
    if not scoring_js.exists():
        pytest.skip("backend not present")
    script = (
        f"const s=require({json.dumps(str(scoring_js))});"
        f"const r=s.rankBids({json.dumps(techs)},{json.dumps(ctx)});"
        "console.log(JSON.stringify(r.map(x=>({id:x.technicianId,score:x.score,reasons:x.reasons,notes:x.notes}))));"
    )
    out = json.loads(subprocess.check_output(["node", "-e", script], text=True))
    py = [{"id": x["technicianId"], "score": x["score"], "reasons": x["reasons"], "notes": x["notes"]}
          for x in scoring.rank_bids(techs, ctx)]
    assert py == out
