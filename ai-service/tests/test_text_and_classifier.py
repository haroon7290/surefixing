import pytest

from app.classifier import classify, model_info
from app.text import stem, tokenize
from app.urgency import detect_urgency

from heldout import HELDOUT


@pytest.mark.parametrize(
    "word,expected",
    [("leaking", "leak"), ("pipes", "pipe"), ("clogged", "clog"), ("batteries", "battery"),
     ("switches", "switch"), ("mosquitoes", "mosquito"), ("dripping", "drip"), ("glass", "glass")],
)
def test_stem(word, expected):
    assert stem(word) == expected


def test_tokenize_drops_stopwords_and_punctuation():
    assert tokenize("Please FIX my leaking pipes!!") == ["leak", "pipe"]


def test_heldout_accuracy():
    """The model must generalise to phrasings it was never trained on."""
    correct = sum(classify(text)["category"] == label for text, label in HELDOUT)
    accuracy = correct / len(HELDOUT)
    assert accuracy >= 0.85, f"held-out accuracy dropped to {accuracy:.0%}"


def test_unknown_text_is_general_with_low_confidence():
    r = classify("hello there")
    assert r["category"] == "general"
    assert r["confidence"] < 0.5


def test_confident_on_clear_text_and_returns_alternatives():
    r = classify("The split AC is blowing warm air and needs a gas refill")
    assert r["category"] == "hvac"
    assert r["confidence"] > 0.6
    assert len(r["categories"]) == 3
    assert "gas refill" in r["keywords"]


@pytest.mark.parametrize(
    "text,level",
    [
        ("Pipe burst and the kitchen is flooding", "emergency"),
        ("I can smell gas near the stove", "normal"),  # "smell gas" isn't an exact trigger phrase
        ("gas smell in the kitchen", "emergency"),
        ("Sink is leaking, please come today", "high"),
        ("Not urgent, paint the gate next week", "low"),
        ("Install a shelf", "normal"),
    ],
)
def test_urgency(text, level):
    assert detect_urgency(text)["urgency"] == level


def test_model_info():
    info = model_info()
    assert len(info["categories"]) == 12
    assert info["vocabulary"] > 500
