"""Route tests for POST /v1/me/sportsz-id/rotate-qr (docs/api/m1.yaml, contract 3).

firebase_auth_service cannot be imported without Firebase credentials, so it is
stubbed before the router import (only if another test file has not already done
so). Authentication is replaced with dependency_overrides and the repository is
monkeypatched, so no MongoDB is needed.
"""
import inspect
import sys
import types
from datetime import datetime

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

_NAME = "app.modules.identity.firebase_auth_service"
if _NAME not in sys.modules:
    _stub = types.ModuleType(_NAME)
    _stub.verify_firebase_token = lambda t: {"token": "jwt", "user_id": "u1", "role": None}
    _stub.set_user_role = lambda uid, role: {"token": "jwt2", "user_id": uid, "role": role}
    _stub.resolve_firebase_user = lambda t: {"user_id": "u1", "firebase_uid": "f1", "role": None}
    sys.modules[_NAME] = _stub

from app.core.errors import register_error_handlers  # noqa: E402
from app.modules.identity import sportsz_id_router  # noqa: E402
from app.modules.identity.profile_repository import ProfileRepository  # noqa: E402

# The exact function objects the route depends on (see tests/test_me_route.py).
get_current_athlete = sportsz_id_router.get_current_athlete
get_current_user = (
    inspect.signature(get_current_athlete).parameters["current_user"].default.dependency
)


def _athlete(user_id):
    return {"user_id": user_id, "firebase_uid": "f-" + user_id, "role": "athlete"}


@pytest.fixture()
def app():
    app = FastAPI()
    register_error_handlers(app)
    app.include_router(sportsz_id_router.router)
    return app


@pytest.fixture()
def client(app):
    return TestClient(app)


@pytest.fixture()
def store(monkeypatch):
    """A fake sports_ids collection: user_id -> document."""
    docs = {
        "uA": {"sportsz_id": "SZ-AAAA-AAA2"},
        "uB": {"sportsz_id": "SZ-BBBB-BBB2"},
    }
    calls = []

    def rotate(user_id, qr_token, rotated_at):
        calls.append(user_id)
        doc = docs.get(user_id)
        if doc is None:
            return None
        doc["qr_token"] = qr_token
        doc["qr_rotated_at"] = rotated_at
        return {"sportsz_id": doc["sportsz_id"]}

    monkeypatch.setattr(ProfileRepository, "rotate_qr_token", staticmethod(rotate))
    return {"docs": docs, "calls": calls}


def test_requires_authentication(client, store):
    r = client.post("/v1/me/sportsz-id/rotate-qr")
    assert r.status_code == 401
    assert store["calls"] == []


def test_non_athlete_is_forbidden(app, client, store):
    app.dependency_overrides[get_current_user] = lambda: {
        "user_id": "uA",
        "firebase_uid": "f-uA",
        "role": "coach",
    }
    r = client.post("/v1/me/sportsz-id/rotate-qr")
    assert r.status_code == 403
    assert store["calls"] == []


def test_response_has_exactly_the_contract_fields(app, client, store):
    app.dependency_overrides[get_current_athlete] = lambda: _athlete("uA")
    body = client.post("/v1/me/sportsz-id/rotate-qr").json()
    assert set(body.keys()) == {"data", "meta"}
    assert set(body["data"].keys()) == {"sportsz_id", "qr_token", "qr_rotated_at"}
    assert body["data"]["sportsz_id"] == "SZ-AAAA-AAA2"
    assert len(body["data"]["qr_token"]) >= 32
    datetime.fromisoformat(body["data"]["qr_rotated_at"])


def test_each_rotation_replaces_the_previous_token(app, client, store):
    app.dependency_overrides[get_current_athlete] = lambda: _athlete("uA")
    first = client.post("/v1/me/sportsz-id/rotate-qr").json()["data"]["qr_token"]
    second = client.post("/v1/me/sportsz-id/rotate-qr").json()["data"]["qr_token"]
    assert first != second
    # Only the newest token is stored; the old one no longer exists anywhere.
    assert store["docs"]["uA"]["qr_token"] == second
    assert first not in store["docs"]["uA"].values()


def test_tokens_are_unique_across_many_rotations(app, client, store):
    app.dependency_overrides[get_current_athlete] = lambda: _athlete("uA")
    tokens = {
        client.post("/v1/me/sportsz-id/rotate-qr").json()["data"]["qr_token"]
        for _ in range(30)
    }
    assert len(tokens) == 30


def test_sportsz_id_never_changes(app, client, store):
    app.dependency_overrides[get_current_athlete] = lambda: _athlete("uA")
    ids = {
        client.post("/v1/me/sportsz-id/rotate-qr").json()["data"]["sportsz_id"]
        for _ in range(3)
    }
    assert ids == {"SZ-AAAA-AAA2"}
    assert store["docs"]["uA"]["sportsz_id"] == "SZ-AAAA-AAA2"


def test_athlete_b_cannot_rotate_athlete_a(app, client, store):
    """Identity comes from the token only; a body naming another user is ignored."""
    app.dependency_overrides[get_current_athlete] = lambda: _athlete("uB")
    r = client.post(
        "/v1/me/sportsz-id/rotate-qr",
        json={"user_id": "uA", "sportsz_id": "SZ-AAAA-AAA2"},
    )
    assert r.status_code == 200
    assert store["calls"] == ["uB"]
    assert "qr_token" in store["docs"]["uB"]
    assert "qr_token" not in store["docs"]["uA"]
    assert r.json()["data"]["sportsz_id"] == "SZ-BBBB-BBB2"


def test_returns_404_when_no_sportsz_id_was_issued(app, client, store):
    app.dependency_overrides[get_current_athlete] = lambda: _athlete("uZ")
    r = client.post("/v1/me/sportsz-id/rotate-qr")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "NOT_FOUND"
    assert r.json()["error"]["message"] == "SportsZ ID has not been issued yet"
