from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.core.dependencies import get_current_athlete
from app.modules.events import service
from app.modules.discovery import service as saved_service
from app.modules.events.repository import InvalidCursor
from app.modules.events.schemas import (
    CancellationResponse,
    EventDetailResponse,
    EventListResponse,
    EventRegistrationResponse,
    MyEventRegistrationsResponse,
)

router = APIRouter(prefix="/v1", tags=["events"])


def _error(status: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status,
        detail={"code": code, "message": message, "details": []},
    )


def _action_error(exc: service.EventActionError) -> HTTPException:
    return _error(exc.status_code, exc.code, exc.message)


@router.get("/events", response_model=EventListResponse)
def list_events(
    request: Request,
    sport_id: Optional[str] = None,
    status: str = Query("upcoming", pattern="^(upcoming|ongoing|completed)$"),
    limit: int = Query(20, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: dict = Depends(get_current_athlete),
):
    try:
        items, next_cursor = service.list_events(
            sport_id, status, limit, cursor, current_user["user_id"]
        )
    except InvalidCursor:
        raise _error(422, "INVALID_CURSOR", "Invalid event cursor")
    return {
        "data": items,
        "meta": {"next_cursor": next_cursor, "request_id": request.state.request_id},
    }


@router.get("/events/{public_id}", response_model=EventDetailResponse)
def get_event(
    public_id: str,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    item = service.get_event(
        public_id,
        current_user["user_id"],
        saved_service.is_saved(current_user["user_id"], "event", public_id),
    )
    if item is None:
        raise _error(404, "NOT_FOUND", "Event not found")
    return {
        "data": item,
        "meta": {"next_cursor": None, "request_id": request.state.request_id},
    }


@router.post("/events/{public_id}/register", response_model=EventRegistrationResponse)
def register_event(
    public_id: str,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    try:
        result = service.register(public_id, current_user["user_id"])
    except service.EventActionError as exc:
        raise _action_error(exc)
    return {
        "data": result,
        "meta": {"next_cursor": None, "request_id": request.state.request_id},
    }


@router.delete(
    "/events/{public_id}/register", response_model=CancellationResponse
)
def cancel_registration(
    public_id: str,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    try:
        service.cancel_registration(public_id, current_user["user_id"])
    except service.EventActionError as exc:
        raise _action_error(exc)
    return {
        "data": {"cancelled": True},
        "meta": {"next_cursor": None, "request_id": request.state.request_id},
    }


@router.get(
    "/me/event-registrations", response_model=MyEventRegistrationsResponse
)
def list_my_registrations(
    request: Request,
    limit: int = Query(20, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: dict = Depends(get_current_athlete),
):
    try:
        items, next_cursor = service.list_my_registrations(
            current_user["user_id"], limit, cursor
        )
    except InvalidCursor:
        raise _error(422, "INVALID_CURSOR", "Invalid registration cursor")
    return {
        "data": items,
        "meta": {"next_cursor": next_cursor, "request_id": request.state.request_id},
    }
