"""SureFix AI service.

Endpoints
---------
GET  /              service info
GET  /health        liveness + model summary
GET  /model/info    classifier stats and scoring weights
POST /analyze       problem text → category (+ confidence) and urgency
POST /recommend     problem + candidate technicians → ranked, explained matches
POST /rank          bids on one job → ranked, explained quotes
POST /score         score a single technician (kept for older backends)

Interactive docs: http://localhost:5001/docs
"""

from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

from . import scoring
from .classifier import classify, model_info
from .training_data import CATEGORY_LABELS
from .urgency import detect_urgency

VERSION = "2.0.0"

app = FastAPI(
    title="SureFix AI Service",
    version=VERSION,
    description="Problem understanding and explainable technician recommendations for SureFix.",
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


class Technician(BaseModel):
    """A candidate technician. Unknown fields (bidId, avatar, …) pass through."""

    model_config = ConfigDict(extra="allow")

    technicianId: Optional[str] = None
    name: Optional[str] = None
    amount: Optional[float] = None
    etaDays: Optional[int] = None
    rating: float = 0.0
    ratingCount: int = 0
    jobsCompleted: int = 0
    jobsAssigned: int = 0
    avgResponseMinutes: Optional[float] = None
    experienceYears: float = 0
    skills: List[str] = Field(default_factory=list)
    headline: Optional[str] = ""
    bio: Optional[str] = ""
    city: Optional[str] = ""
    isAvailable: Optional[bool] = True
    kycStatus: Optional[str] = None


class AnalyzeRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000)


class RecommendRequest(BaseModel):
    description: str = ""
    category: Optional[str] = ""
    city: Optional[str] = ""
    budget: Optional[float] = 0
    urgency: Optional[str] = ""
    technicians: List[Technician] = Field(default_factory=list)


class RankRequest(BaseModel):
    technicians: List[Technician] = Field(default_factory=list)
    jobCategory: Optional[str] = ""
    description: Optional[str] = ""
    budget: Optional[float] = 0
    city: Optional[str] = ""
    urgency: Optional[str] = "normal"


def analyze_text(text: str) -> Dict[str, Any]:
    result = classify(text)
    result.update(detect_urgency(text))
    result["label"] = CATEGORY_LABELS.get(result["category"], result["category"])
    result["engine"] = "naive-bayes"
    return result


def _dump(items: List[Technician]) -> List[Dict[str, Any]]:
    return [t.model_dump() for t in items]


@app.get("/")
def root():
    return {"ok": True, "service": "surefix-ai", "version": VERSION, "docs": "/docs"}


@app.get("/health")
def health():
    info = model_info()
    return {"status": "healthy", "version": VERSION, "categories": len(info["categories"]), "vocabulary": info["vocabulary"]}


@app.get("/model/info")
def info():
    return {
        "classifier": model_info(),
        "weights": {"recommend": scoring.RECOMMEND_WEIGHTS, "bid": scoring.BID_WEIGHTS},
        "urgencyBoost": scoring.URGENCY_BOOST,
        "ratingPrior": {"mean": scoring.RATING_PRIOR_MEAN, "weight": scoring.RATING_PRIOR_WEIGHT},
    }


@app.post("/analyze")
def analyze(req: AnalyzeRequest):
    return analyze_text(req.text)


@app.post("/recommend")
def recommend(req: RecommendRequest):
    analysis = analyze_text(req.description) if req.description.strip() else None
    ctx = {
        "description": req.description,
        "category": req.category or "",
        "city": req.city or "",
        "budget": req.budget or 0,
        "urgency": req.urgency or "",
    }
    ranked = scoring.recommend(_dump(req.technicians), ctx, analysis)
    return {"analysis": analysis, "ranked": ranked}


@app.post("/rank")
def rank(req: RankRequest):
    ctx = {
        "jobCategory": req.jobCategory or "",
        "description": req.description or "",
        "budget": req.budget or 0,
        "city": req.city or "",
        "urgency": req.urgency or "normal",
    }
    return {"ranked": scoring.rank_bids(_dump(req.technicians), ctx)}


@app.post("/score")
def score(t: Technician, jobCategory: str = ""):
    return {"score": scoring.score_one(t.model_dump(), {"category": jobCategory}, "recommend")["score"]}
