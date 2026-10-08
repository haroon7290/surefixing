# AI Ranking Service

Small FastAPI microservice that scores technicians for the backend's
"ranked bids" endpoint.

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Run

```bash
source venv/bin/activate
uvicorn app.main:app --reload --port 5001
```

## Try it

```bash
curl -s -X POST http://localhost:5001/rank \
     -H 'Content-Type: application/json' \
     -d '{"technicians":[
           {"name":"A","rating":4.8,"ratingCount":20,"completionRate":0.95,"responseSpeed":0.9,"jobsCompleted":30},
           {"name":"B","rating":4.0,"ratingCount":3, "completionRate":0.80,"responseSpeed":0.5,"jobsCompleted":5}
         ]}' | python -m json.tool
```

## Scoring weights

Weighted sum scaled to 0–5. See `app/ranker.py` for the canonical values
and `../docs/ARCHITECTURE.md#scoring` for the breakdown:

| Component | Weight |
|---|---|
| rating × confidence(ratingCount) | 0.40 |
| completionRate | 0.25 |
| skillMatch (1 if jobCategory ∈ tech.skills else 0) | 0.15 |
| responseSpeed | 0.10 |
| experience (jobsCompleted/50, capped) | 0.10 |

The Node backend has an identical JS fallback in `backend/src/utils/ai.js`
that runs when this service is unreachable. Keep them in sync if you change
the formula.

## Swap in a real model

Replace `score_one()` in `app/ranker.py` with a trained model. The input
dict contains everything the backend passes; the return must be a 0–5 float.
