# SureFix AI Service

FastAPI microservice that powers SureFix's **Smart Match**:

1. **Problem understanding** — a Naive Bayes text classifier reads a customer's
   description ("water dripping under my kitchen sink") and predicts the
   service category with a confidence score, plus a rule-based urgency level
   (low / normal / high / emergency).
2. **Explainable technician ranking** — every candidate gets a 0–100 match
   score from eight weighted signals, and the strongest signals become
   plain-English reasons ("Specialises in plumbing", "Rated 4.8★ by 21
   clients", "Usually responds in ~15 min").

Pure Python on top of FastAPI — no NumPy/scikit-learn — so it installs
anywhere in seconds. Interactive API docs: <http://localhost:5001/docs>.

## Run

```bat
:: Windows (from the repo root)
scripts\start-ai.bat
```

```bash
# macOS / Linux
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 5001
```

The backend calls this service at `AI_SERVICE_URL` (default
`http://localhost:5001`). If it is not running, the backend uses a built-in
JavaScript port of the same scoring (`backend/src/services/scoring.js`), so
the app keeps working — responses then carry `"engine": "fallback"`.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness + model summary |
| GET | `/model/info` | Classifier stats, weights, rating prior |
| POST | `/analyze` | `{text}` → `{category, label, confidence, categories[3], urgency, urgencyTerms, keywords}` |
| POST | `/recommend` | `{description, category?, city?, budget?, urgency?, technicians[]}` → `{analysis, ranked[]}` |
| POST | `/rank` | `{technicians[] (bids), jobCategory, description?, budget?, city?, urgency?}` → `{ranked[]}` |
| POST | `/score` | one technician → `{score}` (kept for v1 backends) |

Each ranked item keeps every input field and adds
`score` (0–5), `matchPercent` (0–100), `breakdown` (each component 0–1),
`reasons[]` (top 4 positives) and `notes[]` (cautions such as
"New on SureFix — no reviews yet" or "20% over your budget").

```bash
curl -s -X POST localhost:5001/analyze -H 'Content-Type: application/json' \
     -d '{"text":"AC is blowing warm air, please come today"}'
# → {"category":"hvac","label":"AC & heating","confidence":0.83,"urgency":"high",...}
```

## How the model works

### 1. Category classifier (`app/classifier.py`)

* Text → lower-case → stopwords removed → light stemming
  (`leaking→leak`, `pipes→pipe`) → unigrams **and bigrams**
  (`washing machine → wash_machine`).
* Multinomial Naive Bayes with Laplace smoothing (α = 0.5) and uniform
  priors, trained at start-up on `app/training_data.py`: ~160 labelled
  customer descriptions plus a keyword lexicon per category (lexicon phrases
  weigh 3×).
* Confidence = top posterior × an evidence factor (texts with only one or
  two known words can't produce a 99% guess). If the top posterior is under
  0.25 the request is treated as *General handyman*.
* Accuracy on a held-out set of phrasings the model never saw
  (`tests/heldout.py`): **~89%** (12 categories; uniform guessing would be
  8%). The test suite fails if it drops below 85%.

**Teach it new phrasing:** add sentences to `SAMPLES` in
`app/training_data.py` and restart. Never copy `tests/heldout.py` lines into
training, or the accuracy number stops meaning anything.

### 2. Urgency (`app/urgency.py`)

Safety words win (`burst`, `flood`, `sparks`, `gas smell` → *emergency*);
then explicit no-rush phrases (*low*, checked before *high* because
"not urgent" contains "urgent"); then outage/time words
(`leaking`, `not working`, `today` → *high*).

### 3. Scoring (`app/scoring.py`)

| Component | How it is measured | Recommend | Bid |
|---|---|---|---|
| skill | 1 if the category is in the technician's skills, else keyword overlap with skills/headline/bio (max 0.6) | 0.30 | 0.18 |
| rating | Bayesian average `(r·n + 3.5·3)/(n + 3)` ÷ 5 — one 5★ review can't beat forty 4.8★ | 0.22 | 0.24 |
| reliability | smoothed completed ÷ hired jobs | 0.13 | 0.14 |
| responsiveness | `1 / (1 + avgResponseMinutes/60)`, measured from real bid times | 0.08 | 0.08 |
| experience | jobs completed (cap 40) and years of experience (cap 10) | 0.09 | 0.08 |
| proximity | same city 1.0, unknown 0.4, other city 0.1 | 0.08 | 0.05 |
| availability | availability toggle | 0.05 | — |
| verified | KYC-approved ID | 0.05 | 0.05 |
| price (bids) | ½ · (lowest bid ÷ this bid) + ½ · budget fit | — | 0.18 |

For **high** / **emergency** requests the responsiveness and availability
weights are multiplied by 1.5 / 2.0 and all weights re-normalised, so fast,
available technicians rise to the top when it matters.

## Tests

```bash
pip install -r requirements-dev.txt
pytest -q
```

34 tests: stemming, held-out accuracy, urgency, scoring properties (weights
sum to 1, Bayesian damping, urgency boost, price/budget notes), API
contracts, and a **parity test** that runs the backend's JS fallback through
Node and checks it ranks identically to this service.
