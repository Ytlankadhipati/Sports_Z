import sys
import types

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

# firebase_auth_service Firebase credentials ke bina import nahi hota, isliye
# router import se pehle stub karte hain (real Firebase test = emulator suite).
_calls = {}
_service_name = "app.modules.identity.firebase_auth_service"
_dependency_name = "app.core.dependencies"
_previous_service = sys.modules.get(_service_name)
_previous_dependencies = sys.modules.get(_dependency_name)
_stub = types.ModuleType(_service_name)
_stub.verify_firebase_token = lambda t: (
    _calls.setdefault("verify", t) and {"token": "jwt", "user_id": "u1", "role": None}
)
_stub.set_user_role = lambda uid, role: {"token": "jwt2", "user_id": uid, "role": role}
_stub.resolve_firebase_user = lambda t: {"user_id": "u1", "firebase_uid": "f1", "role": None}
sys.modules[_service_name] = _stub
try:
    from app.core.errors import register_error_handlers  # noqa: E402
    from app.modules.identity import auth_router, me_router  # noqa: E402
finally:
    # These routers keep their test stub references, but later application
    # imports (including the profile tests) must load the real auth service.
    if _previous_service is None:
        sys.modules.pop(_service_name, None)
    else:
        sys.modules[_service_name] = _previous_service
    if _previous_dependencies is None:
        sys.modules.pop(_dependency_name, None)
    else:
        sys.modules[_dependency_name] = _previous_dependencies


@pytest.fixture()
def client():
    app = FastAPI()
    register_error_handlers(app)
    app.include_router(auth_router.router)
    app.include_router(me_router.router)
    return TestClient(app)


AUTH = {"Authorization": "Bearer firebase-token"}


def test_session_and_deprecated_verify_alias_both_work(client):
    for path in ("/v1/auth/session", "/v1/auth/verify"):
        r = client.post(path, json={"id_token": "x"})
        assert r.status_code == 200
        assert r.json()["user_id"] == "u1"


def test_session_rejects_extra_fields(client):
    r = client.post("/v1/auth/session", json={"id_token": "x", "role": "admin"})
    assert r.status_code == 422


def test_logout_requires_auth(client):
    assert client.post("/v1/auth/logout").status_code == 401


def test_logout_returns_204_when_authenticated(client):
    r = client.post("/v1/auth/logout", headers=AUTH)
    assert r.status_code == 204
    assert r.content == b""


def test_enroll_athlete_requires_auth(client):
    assert client.post("/v1/me/roles/athlete").status_code == 401


def test_enroll_athlete_sets_role_from_token_not_body(client):
    r = client.post("/v1/me/roles/athlete", headers=AUTH, json={"user_id": "other"})
    assert r.status_code == 200
    assert r.json() == {"token": "jwt2", "user_id": "u1", "role": "athlete"}
