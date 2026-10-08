"""Text normalisation shared by the classifier and the scorer.

Mirrors ``tokenize``/``stem`` in backend/src/services/scoring.js so both
engines see the same tokens. Keep them in sync.
"""

import re
from typing import List

STOPWORDS = set(
    (
        "a an the and or but if of to in on at by for with from into over under is are was were be been "
        "being am i im me my we our you your it its this that these those there here very some any also "
        "just so too can could would should will shall may might must do does did done have has had not "
        "no need needs needed want wants please help someone somebody get got fix fixed fixing repair "
        "repaired repairing service work working come out up down again still what when where how which "
        "who why dont doesnt cant wont isnt about around one two three since than then them they their"
    ).split()
)

_NON_ALPHA = re.compile(r"[^a-z\s]")
_DOUBLE_ES = re.compile(r"(ches|shes|sses|xes|zes)$")


def stem(word: str) -> str:
    """Tiny suffix stripper: leaking→leak, pipes→pipe, clogged→clog."""
    w = word
    if len(w) > 4 and w.endswith("ies"):
        w = w[:-3] + "y"
    elif len(w) > 5 and w.endswith("oes"):
        w = w[:-2]
    elif len(w) > 4 and _DOUBLE_ES.search(w):
        w = w[:-2]
    elif len(w) > 3 and w.endswith("s") and not w.endswith("ss"):
        w = w[:-1]

    stripped = False
    if len(w) > 5 and w.endswith("ing"):
        w, stripped = w[:-3], True
    elif len(w) > 4 and w.endswith("ed"):
        w, stripped = w[:-2], True
    elif len(w) > 4 and w.endswith("er"):
        w, stripped = w[:-2], True
    if stripped and len(w) > 2 and w[-1] == w[-2] and w[-1] not in "lsz":
        w = w[:-1]
    return w


def tokenize(text: str) -> List[str]:
    """Lower-case, strip punctuation, drop stopwords, stem."""
    cleaned = _NON_ALPHA.sub(" ", str(text or "").lower())
    return [stem(t) for t in cleaned.split() if len(t) > 1 and t not in STOPWORDS]


def with_bigrams(tokens: List[str]) -> List[str]:
    """Unigrams plus adjacent bigrams ("washing machine" → "wash_machine")."""
    return tokens + [f"{a}_{b}" for a, b in zip(tokens, tokens[1:])]


def normalise_phrase(text: str) -> str:
    """Lower-case text with punctuation collapsed, padded with spaces."""
    return " " + re.sub(r"\s+", " ", _NON_ALPHA.sub(" ", str(text or "").lower())).strip() + " "
