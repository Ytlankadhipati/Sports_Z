"""M4 HTTP layer tests: envelope, status codes, uniform 404, validation.

Auth (Firebase) is replaced by a header so no credentials are needed; the
real get_current_user -> get_viewer_context chain is covered separately.
"""

import importlib
import sys
import types

import pytest

mongomock = pytest.importorskip("mongomock")
pytest.importorskip("httpx")

from fastapi import Depends, FastAPI, Header  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.errors import register_error_handlers  # noqa: E402
from app.devtools.fixtures import seed_fixtures  # noqa: E402

_MODS = ["app.core.authz.deps", "app.modules.relationships.router", "app.modules.messaging.router",
         "app.devtools.router"]


@pytest.fixture()
def api(monkeypatch):
    stub = types.ModuleType("app.core.dependencies")
    stub.get_current_user = lambda: {}
    monkeypatch.setitem(sys.modules, "app.core.dependencies", stub)
    for m in _MODS:
        sys.modules.pop(m, None)
    deps = importlib.import_module("app.core.authz.deps")
    rel = importlib.import_module("app.modules.relationships.router")
    msg = importlib.import_module("app.modules.messaging.router")
    from app.devtools.router import _viewer
    from app.modules.relationships.container import build_container, get_container

    db = mongomock.MongoClient()["t"]
    container = build_container(db, db["users"], db["athlete_profiles"])
    container.ensure_indexes()
    ids = seed_fixtures(db["users"], db["athlete_profiles"])

    app = FastAPI()
    register_error_handlers(app)
    app.include_router(rel.router)
    app.include_router(msg.router)

    def fake_viewer(x_test_user: str | None = Header(default=None)):
        from fastapi import HTTPException
        if not x_test_user:
            raise HTTPException(401, {"code": "AUTH_REQUIRED", "message": "Authentication required", "details": []})
        return _viewer(container, db["users"], x_test_user)

    app.dependency_overrides[deps.get_viewer_context] = fake_viewer
    app.dependency_overrides[get_container] = lambda: container
    yield TestClient(app), ids, container, deps
    for m in _MODS:
        sys.modules.pop(m, None)


def H(name):
    return {"X-Test-User": name}


def test_requires_auth(api):
    client, *_ = api
    r = client.get("/v1/connections")
    assert r.status_code == 401 and r.json()["error"]["code"] == "AUTH_REQUIRED"


def test_connection_create_envelope_and_flow(api):
    client, ids, *_ = api
    r = client.post("/v1/connections", json={"target_user_id": ids["RECR_V"], "note": "hi"}, headers=H("ATHLETE_1"))
    assert r.status_code == 201
    body = r.json()
    assert body["data"]["status"] == "requested" and "request_id" in body["meta"]
    cid = body["data"]["id"]
    assert client.post(f"/v1/connections/{cid}/respond", json={"decision": "accept"},
                       headers=H("ATHLETE_1")).status_code == 403
    ok = client.post(f"/v1/connections/{cid}/respond", json={"decision": "accept"}, headers=H("RECR_V"))
    assert ok.status_code == 200 and ok.json()["data"]["status"] == "accepted"
    lst = client.get("/v1/connections?status=accepted", headers=H("RECR_V")).json()
    assert len(lst["data"]) == 1 and lst["meta"]["next_cursor"] is None


def test_validation_errors_422(api):
    client, ids, *_ = api
    assert client.post("/v1/connections", json={"target_user_id": ids["RECR_V"], "role": "admin"},
                       headers=H("ATHLETE_1")).status_code == 422          # extra field forbidden
    r = client.post("/v1/connections", json={"target_user_id": ids["RECR_V"], "note": "x" * 141}, headers=H("ATHLETE_1"))
    assert r.status_code == 422 and r.json()["error"]["code"] == "VALIDATION_ERROR"
    assert client.post("/v1/connections/abc/respond", json={"decision": "maybe"},
                       headers=H("RECR_V")).status_code == 422


def test_hidden_and_missing_look_identical(api):
    client, ids, *_ = api
    client.post("/v1/connections/block", json={"target_user_id": ids["ATHLETE_1"]}, headers=H("RECR_V"))
    blocked = client.post("/v1/connections", json={"target_user_id": ids["RECR_V"]}, headers=H("ATHLETE_1"))
    missing = client.post("/v1/connections", json={"target_user_id": "64b000000000000000000000"}, headers=H("ATHLETE_1"))
    assert blocked.status_code == missing.status_code == 404
    assert blocked.json()["error"]["code"] == missing.json()["error"]["code"] == "NOT_FOUND"
    assert blocked.json()["error"]["message"] == missing.json()["error"]["message"]


def test_conversation_flow_and_idor_over_http(api):
    client, ids, *_ = api
    cid = client.post("/v1/connections", json={"target_user_id": ids["COACH_V"]}, headers=H("ATHLETE_1")).json()["data"]["id"]
    client.post(f"/v1/connections/{cid}/respond", json={"decision": "accept"}, headers=H("COACH_V"))
    r = client.post("/v1/conversations", json={"recipient_user_id": ids["COACH_V"], "text": "hello"}, headers=H("ATHLETE_1"))
    assert r.status_code == 201
    conv = r.json()["data"]["conversation_id"]
    assert client.post(f"/v1/conversations/{conv}/messages", json={"text": "hi"}, headers=H("COACH_V")).status_code == 201
    assert len(client.get(f"/v1/conversations/{conv}/messages", headers=H("COACH_V")).json()["data"]["messages"]) == 2
    for method, url in (("get", f"/v1/conversations/{conv}/messages"), ("post", f"/v1/conversations/{conv}/read"),
                        ("delete", f"/v1/conversations/{conv}")):
        assert getattr(client, method)(url, headers=H("ATHLETE_2")).status_code == 404
    assert client.post(f"/v1/conversations/{conv}/read", headers=H("COACH_V")).status_code == 204
    assert client.patch(f"/v1/conversations/{conv}/mute", json={"muted": True}, headers=H("COACH_V")).json()["data"]["muted"]
    assert client.post(f"/v1/conversations/{conv}/messages", json={"text": ""}, headers=H("COACH_V")).status_code == 422


def test_rate_limit_returns_429_with_retry_after(api):
    client, ids, container, _ = api
    container.config._collection = None  # defaults only
    cid = client.post("/v1/connections", json={"target_user_id": ids["COACH_V"]}, headers=H("ATHLETE_1")).json()["data"]["id"]
    client.post(f"/v1/connections/{cid}/respond", json={"decision": "accept"}, headers=H("COACH_V"))
    conv = client.post("/v1/conversations", json={"recipient_user_id": ids["COACH_V"], "text": "m"}, headers=H("ATHLETE_1")).json()["data"]["conversation_id"]
    codes = [client.post(f"/v1/conversations/{conv}/messages", json={"text": "x"}, headers=H("ATHLETE_1")).status_code
             for _ in range(25)]
    assert 429 in codes
    r = client.post(f"/v1/conversations/{conv}/messages", json={"text": "x"}, headers=H("ATHLETE_1"))
    assert r.status_code == 429 and "retry-after" in {k.lower() for k in r.headers}


def test_coach_link_and_grant_routes(api):
    client, ids, *_ = api
    link = client.post("/v1/coach-links", json={"counterpart_user_id": ids["ATHLETE_1"], "sport_id": "cricket"},
                       headers=H("COACH_V"))
    assert link.status_code == 201
    lid = link.json()["data"]["id"]
    assert client.post(f"/v1/coach-links/{lid}/approve", headers=H("ATHLETE_1")).json()["data"]["status"] == "active"
    g = client.post("/v1/access-grants/requests", json={"owner_user_id": ids["ATHLETE_1"], "scopes": ["physical"]},
                    headers=H("COACH_V"))
    assert g.status_code == 201
    gid = g.json()["data"]["id"]
    assert client.post(f"/v1/access-grants/{gid}/grant", headers=H("ATHLETE_1")).json()["data"]["status"] == "active"
    assert client.post(f"/v1/access-grants/{gid}/revoke", headers=H("COACH_V")).status_code == 403
    assert client.post(f"/v1/access-grants/{gid}/revoke", headers=H("ATHLETE_1")).json()["data"]["status"] == "revoked"
    assert client.post(f"/v1/coach-links/{lid}/end", headers=H("ATHLETE_1")).json()["data"]["status"] == "ended"


def test_privacy_schema_and_preview(api):
    client, ids, container, _ = api
    assert client.get("/v1/me/privacy/schema", headers=H("ATHLETE_1")).status_code == 200
    r = client.get("/v1/me/profile/preview?as=public", headers=H("ATHLETE_1"))
    assert r.status_code == 200 and "city" not in r.json()["data"] and "full_name" in r.json()["data"]
    assert client.get("/v1/me/profile/preview?as=admin", headers=H("ATHLETE_1")).status_code == 422
    assert client.get("/v1/me/profile/preview?as=public", headers=H("COACH_V")).status_code == 403
    assert client.get("/v1/me/profile/preview", headers=H("ATHLETE_1")).status_code == 422


def test_active_role_header_must_be_a_held_role(api):
    *_, deps = api
    from app.core.authz import InvalidActiveRole
    from fastapi import HTTPException
    user = {"user_id": "u", "role": "athlete"}
    assert deps.get_viewer_context(user, "athlete").active_role == "athlete"
    with pytest.raises(HTTPException) as e:
        deps.get_viewer_context(user, "admin")
    assert e.value.status_code == 403


def test_devtools_hidden_when_disabled(monkeypatch):
    monkeypatch.delenv("DEV_TOOLS_ENABLED", raising=False)
    from app.devtools.router import dev_tools_enabled, require_dev_tools
    from fastapi import HTTPException
    assert not dev_tools_enabled()
    with pytest.raises(HTTPException) as e:
        require_dev_tools()
    assert e.value.status_code == 404
    monkeypatch.setenv("DEV_TOOLS_ENABLED", "true")
    assert dev_tools_enabled()
