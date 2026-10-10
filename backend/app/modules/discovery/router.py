from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response

from app.core.dependencies import get_current_athlete
from app.modules.discovery import service
from app.modules.discovery.repository import InvalidCursor
from app.modules.discovery.schemas import (
    SavedCreateRequest,
    SavedItemResponse,
    SavedListResponse,
    SavedType,
)

router = APIRouter(prefix="/v1/saved", tags=["saved"])


def _error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message, "details": []},
    )


@router.post("", response_model=SavedItemResponse)
def save_item(
    body: SavedCreateRequest,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    try:
        item = service.save_item(
            current_user["user_id"], body.type, body.target_id
        )
    except service.SavedActionError as exc:
        raise _error(exc.status_code, exc.code, exc.message)
    return {
        "data": item,
        "meta": {"next_cursor": None, "request_id": request.state.request_id},
    }


@router.delete("/{type}/{target_id}", status_code=204)
def remove_item(
    type: SavedType,
    target_id: str,
    current_user: dict = Depends(get_current_athlete),
):
    service.remove_item(current_user["user_id"], type, target_id)
    return Response(status_code=204)


@router.get("", response_model=SavedListResponse)
def list_items(
    request: Request,
    type: Optional[SavedType] = None,
    limit: int = Query(20, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: dict = Depends(get_current_athlete),
):
    try:
        items, next_cursor = service.list_items(
            current_user["user_id"], type, limit, cursor
        )
    except InvalidCursor:
        raise _error(422, "INVALID_CURSOR", "Invalid saved cursor")
    return {
        "data": items,
        "meta": {"next_cursor": next_cursor, "request_id": request.state.request_id},
    }
