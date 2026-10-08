"""Multinomial Naive Bayes classifier for home-repair problem descriptions.

Pure Python (no NumPy / scikit-learn) so the service installs anywhere.
Trained at import time on ``training_data`` — a few hundred short
examples plus keyword lexicons — which takes a few milliseconds.

Features are stemmed unigrams + bigrams. Priors are uniform so categories
with more examples aren't favoured. Posterior probabilities are tempered
by how much known evidence the text contains, so "hello" doesn't come back
as a confident guess.
"""

import math
from collections import Counter, defaultdict
from typing import Dict, List, Tuple

from .text import tokenize, with_bigrams
from .training_data import LEXICON, SAMPLES

ALPHA = 0.5            # Laplace smoothing
LEXICON_WEIGHT = 3     # one lexicon phrase counts like three sample mentions
MIN_PROBABILITY = 0.25  # top posterior below this → treat as "general" (uniform is ~0.08)


class NaiveBayes:
    def __init__(self) -> None:
        self.counts: Dict[str, Counter] = defaultdict(Counter)
        self.totals: Dict[str, int] = {}
        self.vocab: set = set()
        self.samples = 0

    def fit(self, docs: List[Tuple[str, List[str], int]]) -> "NaiveBayes":
        for label, features, weight in docs:
            for f in features:
                self.counts[label][f] += weight
                self.vocab.add(f)
            self.samples += 1
        self.totals = {c: sum(cnt.values()) for c, cnt in self.counts.items()}
        return self

    @property
    def labels(self) -> List[str]:
        return sorted(self.counts)

    def log_scores(self, features: List[str]) -> Tuple[Dict[str, float], int]:
        known = [f for f in features if f in self.vocab]
        v = len(self.vocab)
        scores = {}
        for c in self.labels:
            denom = self.totals[c] + ALPHA * v
            scores[c] = sum(math.log((self.counts[c][f] + ALPHA) / denom) for f in known)
        return scores, len(known)

    def predict_proba(self, features: List[str]) -> Tuple[List[Tuple[str, float]], int]:
        scores, known = self.log_scores(features)
        if known == 0:
            return [], 0
        top = max(scores.values())
        exp = {c: math.exp(s - top) for c, s in scores.items()}
        z = sum(exp.values())
        ranked = sorted(((c, e / z) for c, e in exp.items()), key=lambda x: -x[1])
        return ranked, known


def _training_docs() -> List[Tuple[str, List[str], int]]:
    docs = []
    for label, sentences in SAMPLES.items():
        for s in sentences:
            docs.append((label, with_bigrams(tokenize(s)), 1))
    for label, terms in LEXICON.items():
        for term in terms:
            toks = tokenize(term) or [term.replace(" ", "_")]
            feats = with_bigrams(toks)
            # A phrase's bigram is the strongest signal ("washing machine").
            docs.append((label, feats, LEXICON_WEIGHT))
    return docs


MODEL = NaiveBayes().fit(_training_docs())


def _matched_keywords(tokens: List[str]) -> List[str]:
    found = []
    token_str = " " + " ".join(tokens) + " "
    for terms in LEXICON.values():
        for term in terms:
            stemmed = " ".join(tokenize(term))
            if stemmed and f" {stemmed} " in token_str and term not in found:
                found.append(term)
    return found[:8]


def classify(text: str) -> dict:
    tokens = tokenize(text)
    ranked, known = MODEL.predict_proba(with_bigrams(tokens))
    if not ranked:
        return {
            "category": "general",
            "confidence": 0.2,
            "categories": [{"category": "general", "confidence": 0.2}],
            "keywords": [],
            "knownTokens": 0,
        }
    # Thin evidence (1–2 known features) shouldn't produce a 99% guess.
    evidence = min(1.0, known / 3.0)
    top_label, top_p = ranked[0]
    confidence = round(top_p * (0.55 + 0.45 * evidence), 3)
    category = top_label if top_p >= MIN_PROBABILITY else "general"
    return {
        "category": category,
        "confidence": confidence,
        "categories": [{"category": c, "confidence": round(p, 3)} for c, p in ranked[:3]],
        "keywords": _matched_keywords(tokens),
        "knownTokens": known,
    }


def model_info() -> dict:
    return {
        "type": "multinomial-naive-bayes",
        "features": "stemmed unigrams + bigrams",
        "categories": MODEL.labels,
        "vocabulary": len(MODEL.vocab),
        "trainingDocuments": MODEL.samples,
        "samplesPerCategory": {c: len(s) for c, s in SAMPLES.items()},
    }
