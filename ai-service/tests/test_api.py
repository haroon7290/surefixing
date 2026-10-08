from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_and_health():
    assert client.get("/").json()["service"] == "surefix-ai"
    health = client.get("/health").json()
    assert health["status"] == "healthy"
    assert health["categories"] == 12


def test_model_info():
    info = client.get("/model/info").json()
    assert info["classifier"]["type"] == "multinomial-naive-bayes"
    assert set(info["weights"]) == {"recommend", "bid"}


def test_analyze():
    r = client.post("/analyze", json={"text": "Sparks from the socket and the breaker keeps tripping"}).json()
    assert r["category"] == "electrical"
    assert r["label"] == "Electrical"
    assert r["urgency"] == "emergency"
    assert r["engine"] == "naive-bayes"


def test_analyze_validates_input():
    assert client.post("/analyze", json={"text": ""}).status_code == 422


def test_recommend_ranks_and_passes_fields_through():
    body = {
        "description": "My fridge is not cooling",
        "city": "Lahore",
        "technicians": [
            {"technicianId": "1", "name": "Plumber", "skills": ["plumbing"], "rating": 4.9, "ratingCount": 30, "avatar": "a.png"},
            {"technicianId": "2", "name": "Appliance pro", "skills": ["appliance"], "rating": 4.3, "ratingCount": 8, "city": "Lahore"},
        ],
    }
    r = client.post("/recommend", json=body).json()
    assert r["analysis"]["category"] == "appliance"
    assert r["ranked"][0]["technicianId"] == "2"
    assert r["ranked"][1]["avatar"] == "a.png"  # extra fields survive
    assert r["ranked"][0]["reasons"]


def test_rank_v1_payload_still_works():
    """Older backends send only these fields."""
    body = {
        "technicians": [
            {"name": "A", "rating": 4.8, "ratingCount": 20, "completionRate": 0.95, "responseSpeed": 0.9, "jobsCompleted": 30},
            {"name": "B", "rating": 4.0, "ratingCount": 3, "completionRate": 0.8, "responseSpeed": 0.5, "jobsCompleted": 5},
        ]
    }
    ranked = client.post("/rank", json=body).json()["ranked"]
    assert [t["name"] for t in ranked] == ["A", "B"]
    assert 0 <= ranked[0]["score"] <= 5


def test_score_endpoint():
    r = client.post("/score?jobCategory=plumbing", json={"skills": ["plumbing"], "rating": 4.5, "ratingCount": 10}).json()
    assert 0 < r["score"] <= 5
