"""M4 routes: connections, coach links, access grants, privacy. Thin: logic is in service.py."""

from __future__ import annotations

from typing import Callable, Literal

from fastapi import APIRouter, Depends, Query, Request, Response

from app.core.authz import ViewerContext
from app.core.authz.deps import get_viewer_context
from app.core.response import success_response
from app.modules.relationships import privacy
from app.modules.relationships.container import M4Container, get_container
from app.modules.relationships.errors import DomainError, ForbiddenError, NotFoundError, to_http
from app.modules.relationships.schemas import (
    BlockCreate,
    CoachLinkCreate,
    ConnectionCreate,
    ConnectionRespond,
    GrantApprove,
    GrantCreate,
    GrantRequestCreate,
)

router = APIRouter(prefix="/v1", tags=["M4 - Relationships & Privacy"])


def _rid(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


def _run(fn: Callable, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except DomainError as exc:
        raise to_http(exc)


def _statuses(value: str | None) -> list[str] | None:
    return [s for s in (value or "").split(",") if s] or None


# ---------------- connections (C01, C02, PR09) ----------------
@router.post("/connections", status_code=201)
def create_connection(body: ConnectionCreate, request: Request,
                      viewer: ViewerContext = Depends(get_viewer_context),
                      c: M4Container = Depends(get_container)):
    data = _run(c.connections.request, viewer, body.target_user_id, body.note)
    return success_response(data, request_id=_rid(request))


@router.get("/connections")
def list_connections(request: Request, status: str | None = Query(None, description="comma separated"),
                     limit: int = Query(20, ge=1, le=50), cursor: str | None = None,
                     viewer: ViewerContext = Depends(get_viewer_context),
                     c: M4Container = Depends(get_container)):
    items, nxt = _run(c.connections.list, viewer, _statuses(status), limit, cursor)
    return success_response(items, request_id=_rid(request), next_cursor=nxt)


@router.post("/connections/block")
def block_user(body: BlockCreate, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
               c: M4Container = Depends(get_container)):
    return success_response(_run(c.connections.block, viewer, body.target_user_id), request_id=_rid(request))


@router.post("/connections/{connection_id}/respond")
def respond_connection(connection_id: str, body: ConnectionRespond, request: Request,
                       viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    return success_response(_run(c.connections.respond, viewer, connection_id, body.decision),
                            request_id=_rid(request))


@router.post("/connections/{connection_id}/block")
def block_connection(connection_id: str, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                     c: M4Container = Depends(get_container)):
    return success_response(_run(c.connections.block_by_connection, viewer, connection_id),
                            request_id=_rid(request))


@router.post("/connections/{connection_id}/unblock", status_code=204)  # TODO(confirm) open item
def unblock_connection(connection_id: str, viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    _run(c.connections.unblock, viewer, connection_id)
    return Response(status_code=204)


# ---------------- coach links (L01, L02) ----------------
@router.get("/coach-links")
def list_coach_links(request: Request, status: str | None = None, limit: int = Query(20, ge=1, le=50),
                     cursor: str | None = None, viewer: ViewerContext = Depends(get_viewer_context),
                     c: M4Container = Depends(get_container)):
    items, nxt = _run(c.links.list, viewer, _statuses(status), limit, cursor)
    return success_response(items, request_id=_rid(request), next_cursor=nxt)


@router.post("/coach-links", status_code=201)
def create_coach_link(body: CoachLinkCreate, request: Request,
                      viewer: ViewerContext = Depends(get_viewer_context),
                      c: M4Container = Depends(get_container)):
    return success_response(_run(c.links.request, viewer, body.counterpart_user_id, body.sport_id),
                            request_id=_rid(request))


@router.post("/coach-links/{link_id}/approve")
def approve_coach_link(link_id: str, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    return success_response(_run(c.links.approve, viewer, link_id), request_id=_rid(request))


@router.post("/coach-links/{link_id}/decline")  # TODO(confirm) open item
def decline_coach_link(link_id: str, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    return success_response(_run(c.links.decline, viewer, link_id), request_id=_rid(request))


@router.post("/coach-links/{link_id}/end")
def end_coach_link(link_id: str, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                   c: M4Container = Depends(get_container)):
    return success_response(_run(c.links.end, viewer, link_id), request_id=_rid(request))


# ---------------- access grants (PR06, PR07) ----------------
@router.get("/access-grants")
def list_grants(request: Request, role: Literal["owner", "grantee"] | None = None, status: str | None = None,
                limit: int = Query(20, ge=1, le=50), cursor: str | None = None,
                viewer: ViewerContext = Depends(get_viewer_context),
                c: M4Container = Depends(get_container)):
    items, nxt = _run(c.grants.list, viewer, role, _statuses(status), limit, cursor)
    return success_response(items, request_id=_rid(request), next_cursor=nxt)


@router.post("/access-grants/requests", status_code=201)
def request_grant(body: GrantRequestCreate, request: Request,
                  viewer: ViewerContext = Depends(get_viewer_context),
                  c: M4Container = Depends(get_container)):
    return success_response(_run(c.grants.request_access, viewer, body.owner_user_id, body.scopes),
                            request_id=_rid(request))


@router.post("/access-grants", status_code=201)  # TODO(confirm) open item
def create_grant(body: GrantCreate, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                 c: M4Container = Depends(get_container)):
    return success_response(_run(c.grants.create_direct, viewer, body.grantee_user_id, body.scopes, body.expires_at),
                            request_id=_rid(request))


@router.post("/access-grants/{grant_id}/grant")
def approve_grant(grant_id: str, request: Request, body: GrantApprove | None = None,
                  viewer: ViewerContext = Depends(get_viewer_context),
                  c: M4Container = Depends(get_container)):
    return success_response(_run(c.grants.grant, viewer, grant_id, body.expires_at if body else None),
                            request_id=_rid(request))


@router.post("/access-grants/{grant_id}/decline")
def decline_grant(grant_id: str, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                  c: M4Container = Depends(get_container)):
    return success_response(_run(c.grants.decline, viewer, grant_id), request_id=_rid(request))


@router.post("/access-grants/{grant_id}/revoke")
def revoke_grant(grant_id: str, request: Request, viewer: ViewerContext = Depends(get_viewer_context),
                 c: M4Container = Depends(get_container)):
    return success_response(_run(c.grants.revoke, viewer, grant_id), request_id=_rid(request))


# ---------------- privacy (PR01, PR08) ----------------
@router.get("/me/privacy/schema")
def get_privacy_schema(request: Request, viewer: ViewerContext = Depends(get_viewer_context)):
    return success_response(privacy.privacy_schema(), request_id=_rid(request))


@router.get("/me/profile/preview")
def preview_my_profile(request: Request, as_: str = Query(..., alias="as"),
                       viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    if viewer.active_role != "athlete":
        raise to_http(ForbiddenError("Athlete role is required for this resource"))
    profile = c.load_profile(viewer.user_id)
    if profile is None:
        raise to_http(NotFoundError("Profile not found"))
    data = _run(privacy.preview_profile, profile, viewer.user_id, as_)
    return success_response(data, request_id=_rid(request))
