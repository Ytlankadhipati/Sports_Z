"""Route-level tests for GET /v1/me (contract: docs/api/m1.yaml, contract 1).

Pattern follows tests/test_auth_v3_routes.py: firebase_auth_service cannot be
imported without Firebase credentials, so it is stubbed before the router import
(only if another test file has not already stubbed it). Authentication is replaced
with dependency_overrides, and the repository is monkeypatched (no MongoDB needed).
"""
import sys
import types

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
from app.modules.identity import me_router  # noqa: E402

# Use the exact function object the route depends on. Importing it from
# app.core.dependencies can give a different object if another test file stubs
# that module, and then dependency_overrides would silently not match.
get_current_user = me_router.get_current_user

FULL_EMAIL = "ravi.kumar@example.com"
FULL_PHONE = "+919876543210"


def _user(user_id="uA"):
    return {
        "user_id": user_id,
        "firebase_uid": "f-" + user_id,
        "role": "athlete",
        "claims": {
            "email": FULL_EMAIL,
            "email_verified": True,
            "phone_number": FULL_PHONE,
            "providers": ["email", "phone", "google.com"],
        },
    }


@pytest.fixture()
def app():
    app = FastAPI()
    register_error_handlers(app)
    app.include_router(me_router.router)
    return app


@pytest.fixture()
def repo_calls(monkeypatch):
    calls = {"profile": [], "sportsz": []}

    def get_profile(uid):
        calls["profile"].append(uid)
        return {"full_name": "Ravi Kumar"}

    def get_sz(uid):
        calls["sportsz"].append(uid)
        return {"sportsz_id": "SZ-4K7M-91Q2-7"}

    monkeypatch.setattr(me_router.ProfileRepository, "get_by_user_id", staticmethod(get_profile))
    monkeypatch.setattr(me_router.ProfileRepository, "get_sportsz_id", staticmethod(get_sz))
    return calls


def test_get_me_requires_auth(app):
    r = TestClient(app).get("/v1/me")
    assert r.status_code == 401


def test_get_me_rejects_non_bearer_scheme(app):
    r = TestClient(app).get("/v1/me", headers={"Authorization": "Basic abc"})
    assert r.status_code == 401


def test_get_me_returns_contract_shape(app, repo_calls):
    app.dependency_overrides[get_current_user] = lambda: _user("uA")
    r = TestClient(app).get("/v1/me")
    assert r.status_code == 200
    body = r.json()
    assert set(body.keys()) == {"data", "meta"}
    assert set(body["data"].keys()) == {
        "user_id", "full_name", "account_label", "email_masked", "email_verified",
        "phone_masked", "phone_verified", "linked_providers", "roles", "sportsz_id",
    }
    d = body["data"]
    assert d["user_id"] == "uA"
    assert d["full_name"] == "Ravi Kumar"
    assert d["sportsz_id"] == "SZ-4K7M-91Q2-7"
    assert d["roles"] == ["athlete"]
    assert d["email_verified"] is True and d["phone_verified"] is True
    assert d["linked_providers"] == ["email", "phone", "google.com"]


def test_get_me_never_returns_full_email_or_phone(app, repo_calls):
    app.dependency_overrides[get_current_user] = lambda: _user("uA")
    r = TestClient(app).get("/v1/me")
    assert FULL_EMAIL not in r.text
    assert "9876543210" not in r.text
    assert "firebase_uid" not in r.text


def test_get_me_identity_comes_only_from_token(app, repo_calls):
    """User B asking with user A's id in the query must still get B's own record."""
    app.dependency_overrides[get_current_user] = lambda: _user("uB")
    r = TestClient(app).get("/v1/me?user_id=uA")
    assert r.status_code == 200
    assert r.json()["data"]["user_id"] == "uB"
    assert repo_calls["profile"] == ["uB"]
    assert repo_calls["sportsz"] == ["uB"]


def test_get_me_works_before_profile_exists(app, monkeypatch):
    monkeypatch.setattr(me_router.ProfileRepository, "get_by_user_id", staticmethod(lambda uid: None))
    monkeypatch.setattr(me_router.ProfileRepository, "get_sportsz_id", staticmethod(lambda uid: None))
    app.dependency_overrides[get_current_user] = lambda: _user("uA")
    r = TestClient(app).get("/v1/me")
    assert r.status_code == 200
    assert r.json()["data"]["full_name"] is None
    assert r.json()["data"]["sportsz_id"] is None