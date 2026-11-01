"""Tests for GET /v1/id/{sportsz_id} (contract: docs/api/m1.yaml, contract 5).

The repository is monkeypatched, so no MongoDB is needed. No authentication is
involved: the route is public on purpose.
"""
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.errors import register_error_handlers
from app.modules.identity import public_id_router
from app.modules.identity.profile_repository import ProfileRepository

GOOD_ID = "SZ-PH4Z-R6FF"

# A profile document that also holds data which must NEVER be public.
FULL_PROFILE = {
    "user_id": "u1",
    "full_name": "Ayush Awasthi G",
    "photo_url": "https://example.com/p.jpg",
    "date_of_birth": "2008-01-02",
    "gender": "male",
    "city": "Lucknow",
    "bio": "private bio",
    "phone": "+919876543210",
    "email": "ayush@example.com",
    "sport_profiles": [
        {
            "sport_id": "s-cricket",
            "sport_name": "Cricket",
            "positions": ["Batter"],
            "level": "State",
            "is_primary": False,
        },
        {
            "sport_id": "s-football",
            "sport_name": "Football",
            "positions": ["Striker", "Winger"],
            "level": "District",
            "is_primary": True,
        },
    ],
}


@pytest.fixture()
def client():
    app = FastAPI()
    register_error_handlers(app)
    app.include_router(public_id_router.router)
    return TestClient(app)


@pytest.fixture()
def db(monkeypatch):
    calls = {"lookup": [], "profile": []}
    state = {"user_id": "u1", "profile": FULL_PROFILE}

    def lookup(sportsz_id):
        calls["lookup"].append(sportsz_id)
        return state["user_id"]

    def profile(user_id):
        calls["profile"].append(user_id)
        return state["profile"]

    monkeypatch.setattr(ProfileRepository, "get_user_id_by_sportsz_id", staticmethod(lookup))
    monkeypatch.setattr(ProfileRepository, "get_public_profile", staticmethod(profile))
    monkeypatch.setattr(ProfileRepository, "get_sport_by_id", staticmethod(lambda sid: None))
    calls["state"] = state
    return calls


def test_public_page_needs_no_authentication(client, db):
    r = client.get(f"/v1/id/{GOOD_ID}")
    assert r.status_code == 200


def test_response_keys_are_exactly_the_whitelist(client, db):
    body = client.get(f"/v1/id/{GOOD_ID}").json()
    assert set(body.keys()) == {"data", "meta"}
    assert set(body["data"].keys()) == {
        "sportsz_id",
        "full_name",
        "photo_url",
        "primary_sport",
        "playing_role",
    }


def test_response_values_use_the_primary_sport(client, db):
    data = client.get(f"/v1/id/{GOOD_ID}").json()["data"]
    assert data["sportsz_id"] == GOOD_ID
    assert data["full_name"] == "Ayush Awasthi G"
    assert data["photo_url"] == "https://example.com/p.jpg"
    assert data["primary_sport"] == "Football"
    assert data["playing_role"] == "Striker \u00b7 Winger"


def test_private_data_is_never_returned(client, db):
    text = client.get(f"/v1/id/{GOOD_ID}").text
    for secret in (
        "2008-01-02",
        "date_of_birth",
        "Lucknow",
        "private bio",
        "9876543210",
        "ayush@example.com",
        "user_id",
        "u1",
        "District",
        "level",
        "verification",
        "documents",
    ):
        assert secret not in text


def test_missing_optional_data_returns_nulls(client, db):
    db["state"]["profile"] = {"full_name": "Ravi"}
    data = client.get(f"/v1/id/{GOOD_ID}").json()["data"]
    assert data["full_name"] == "Ravi"
    assert data["photo_url"] is None
    assert data["primary_sport"] is None
    assert data["playing_role"] is None


@pytest.mark.parametrize(
    "bad_id",
    [
        "sz-ph4z-r6ff",  # lowercase
        "SZ-PH4Z",  # too short
        "SZ-PH4Z-R6FF-7",  # extra segment
        "SZ-PH4Z-R6F0",  # '0' is not in the alphabet
        "SZ-PH4Z-R6FI",  # 'I' is not in the alphabet
        "XX-PH4Z-R6FF",
        "SZ-PH4Z-R6FF%20",
        "..",
        "1" * 300,
    ],
)
def test_malformed_id_is_rejected_without_a_database_query(client, db, bad_id):
    r = client.get(f"/v1/id/{bad_id}")
    assert r.status_code == 404
    assert db["lookup"] == []
    assert db["profile"] == []


def test_unknown_and_malformed_ids_give_identical_answers(client, db):
    db["state"]["user_id"] = None
    unknown = client.get(f"/v1/id/{GOOD_ID}")
    malformed = client.get("/v1/id/not-an-id")
    assert unknown.status_code == malformed.status_code == 404
    assert unknown.json() == malformed.json()
    assert unknown.json()["error"]["code"] == "NOT_FOUND"
    assert unknown.json()["error"]["message"] == "Not found"


def test_id_without_profile_gives_the_same_answer(client, db):
    db["state"]["profile"] = None
    missing_profile = client.get(f"/v1/id/{GOOD_ID}")
    malformed = client.get("/v1/id/not-an-id")
    assert missing_profile.status_code == 404
    assert missing_profile.json() == malformed.json()


def test_disabled_page_gives_the_same_answer(client, db, monkeypatch):
    from app.modules.identity import public_id_service

    monkeypatch.setattr(public_id_service, "is_public_page_enabled", lambda profile: False)
    disabled = client.get(f"/v1/id/{GOOD_ID}")
    malformed = client.get("/v1/id/not-an-id")
    assert disabled.status_code == 404
    assert disabled.json() == malformed.json()
