from typing import List, Optional
from fastapi import FastAPI
from pydantic import BaseModel, Field

from .ranker import rank, score_one

app = FastAPI(title="FixIt AI Ranking Service", version="1.0.0")


class Technician(BaseModel):
    bidId: Optional[str] = None
    technicianId: Optional[str] = None
    name: Optional[str] = None
    amount: Optional[float] = None
    etaDays: Optional[int] = None
    message: Optional[str] = None
    rating: float = 0.0
    ratingCount: int = 0
    jobsCompleted: int = 0
    completionRate: float = 0.0
    responseSpeed: float = 0.0
    avgResponseMinutes: Optional[float] = None

    class Config:
        extra = "allow"


class RankRequest(BaseModel):
    technicians: List[Technician] = Field(default_factory=list)
    jobCategory: Optional[str] = ""


@app.get("/")
def root():
    return {"ok": True, "service": "fixit-ai"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/rank")
def rank_endpoint(req: RankRequest):
    raw = [t.model_dump() for t in req.technicians]
    return {"ranked": rank(raw, req.jobCategory or "")}


@app.post("/score")
def score_endpoint(t: Technician):
    return {"score": score_one(t.model_dump())}
