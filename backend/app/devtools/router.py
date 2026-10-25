"""Dev Counterpart Console (S-13): act AS a fixture user so one tester can exercise both sides.

Disabled unless DEV_TOOLS_ENABLED=true (404 otherwise, like any unknown route).
Real services are called, so real rules apply (no shortcuts around authorize()).
"""

from __future__ import annotations

import os
from typing import Any, Literal

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict

from app.core.authz import ViewerContext
from app.core.errors import not_found
from app.core.response import success_response
from app.devtools.fixtures import FIXTURES, fixture_uid, reset_fixture_data, seed_fixtures
from app.modules.relationships.container import M4Container, get_container
from app.modules.relationships.errors import DomainError, ValidationFailed, to_http


def dev_tools_enabled() -> bool:
    return os.getenv("DEV_TOOLS_ENABLED", "").lower() == "true"


def require_dev_tools() -> None:
    if not dev_tools_enabled():
        raise not_found()


router = APIRouter(prefix="/v1/devtools", tags=["M4 - Dev tools"], dependencies=[Depends(require_dev_tools)])


class ActRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    fixture: str
    action: Literal["connect", "respond_connection", "link_request", "approve_link", "end_link",
                    "message", "reply", "request_grant", "block"]
    target_user_id: str | None = None
    ref_id: str | None = None          # connection / link / conversation id
    text: str | None = None
    sport_id: str | None = None
    decision: Literal["accept", "decline"] = "accept"
    scopes: list[str] | None = None


def _viewer(c: M4Container, users, name: str) -> ViewerContext:
    u = users.find_one({"firebase_uid": fixture_uid(name)})
    if u is None:
        raise ValidationFailed("Fixtures not seeded. Call POST /v1/devtools/seed first.")
    verified = u.get("verification_status") == "verified"
    role = u["role"]
    return ViewerContext(str(u["_id"]), frozenset({role}), role, bool(u.get("platform_blocked")),
                         coach_verified=verified and role == "coach",
                         recruiter_verified=verified and role == "recruiter")


def perform(c: M4Container, users, req: ActRequest) -> Any:
    if req.fixture not in FIXTURES:
        raise ValidationFailed(f"Unknown fixture. Use one of: {', '.join(FIXTURES)}")
    v = _viewer(c, users, req.fixture)
    need = lambda x, n: x or (_ for _ in ()).throw(ValidationFailed(f"{n} is required"))  # noqa: E731
    a = req.action
    if a == "connect":
        return c.connections.request(v, need(req.target_user_id, "target_user_id"), req.text)
    if a == "respond_connection":
        return c.connections.respond(v, need(req.ref_id, "ref_id"), req.decision)
    if a == "link_request":
        return c.links.request(v, need(req.target_user_id, "target_user_id"), need(req.sport_id, "sport_id"))
    if a == "approve_link":
        return c.links.approve(v, need(req.ref_id, "ref_id"))
    if a == "end_link":
        return c.links.end(v, need(req.ref_id, "ref_id"))
    if a == "message":
        return c.messaging.start(v, need(req.target_user_id, "target_user_id"), need(req.text, "text"))
    if a == "reply":
        return c.messaging.send(v, need(req.ref_id, "ref_id"), need(req.text, "text"))
    if a == "request_grant":
        return c.grants.request_access(v, need(req.target_user_id, "target_user_id"), req.scopes or ["profile_full"])
    if a == "block":
        return c.connections.block(v, need(req.target_user_id, "target_user_id"))
    raise ValidationFailed("Unsupported action")


@router.post("/seed")
def seed(request: Request, c: M4Container = Depends(get_container)):
    from app.core.database import athlete_profiles_collection, users_collection
    c.config.seed_defaults()
    return success_response(seed_fixtures(users_collection, athlete_profiles_collection),
                            request_id=getattr(request.state, "request_id", None))


@router.post("/reset")
def reset(request: Request, c: M4Container = Depends(get_container)):
    from app.core.database import athlete_profiles_collection, db, users_collection
    ids = seed_fixtures(users_collection, athlete_profiles_collection)
    return success_response(reset_fixture_data(db, ids), request_id=getattr(request.state, "request_id", None))


@router.post("/act")
def act(body: ActRequest, request: Request, c: M4Container = Depends(get_container)):
    from app.core.database import users_collection
    try:
        data = perform(c, users_collection, body)
    except DomainError as exc:
        raise to_http(exc)
    return success_response(data, request_id=getattr(request.state, "request_id", None))
