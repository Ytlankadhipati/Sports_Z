from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.core.dependencies import get_current_user
from app.modules.events import service
from app.modules.events.repository import InvalidCursor
from app.modules.events.schemas import EventDetailResponse, EventListResponse

router = APIRouter(prefix="/v1/events", tags=["events"])


def _error(status: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status,
        detail={"code": code, "message": message, "details": []},
    )


@router.get("", response_model=EventListResponse)
def list_events(
    request: Request,
    sport_id: Optional[str] = None,
    status: str = Query("upcoming", pattern="^(upcoming|ongoing|completed)$"),
    limit: int = Query(20, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    try:
        items, next_cursor = service.list_events(sport_id, status, limit, cursor)
    except InvalidCursor:
        raise _error(422, "INVALID_CURSOR", "Invalid cursor")
    return {"data": items, "meta": {"next_cursor": next_cursor, "request_id": request.state.request_id}}


@router.get("/{public_id}", response_model=EventDetailResponse)
def get_event(
    public_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    item = service.get_event(public_id)
    if item is None:
        raise _error(404, "NOT_FOUND", "Event not found")
    return {"data": item, "meta": {"next_cursor": None, "request_id": request.state.request_id}}
