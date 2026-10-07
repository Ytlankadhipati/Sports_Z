from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.core.dependencies import get_current_user
from app.modules.opportunities import service
from app.modules.opportunities.repository import InvalidCursor
from app.modules.opportunities.schemas import (
    OpportunityDetailResponse,
    OpportunityListResponse,
)

router = APIRouter(prefix="/v1/opportunities", tags=["opportunities"])


def _error(status: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status,
        detail={"code": code, "message": message, "details": []},
    )


@router.get("", response_model=OpportunityListResponse)
def list_opportunities(
    request: Request,
    sport_id: Optional[str] = None,
    type: Optional[str] = Query(None, pattern="^(trial|scholarship|job|camp)$"),
    status: str = Query("open", pattern="^(open|closed)$"),
    limit: int = Query(20, ge=1, le=50),
    cursor: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    try:
        items, next_cursor = service.list_opportunities(sport_id, type, status, limit, cursor)
    except InvalidCursor:
        raise _error(422, "INVALID_CURSOR", "Invalid cursor")
    return {"data": items, "meta": {"next_cursor": next_cursor, "request_id": request.state.request_id}}


@router.get("/{public_id}", response_model=OpportunityDetailResponse)
def get_opportunity(
    public_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    item = service.get_opportunity(public_id)
    if item is None:
        raise _error(404, "NOT_FOUND", "Opportunity not found")
    return {"data": item, "meta": {"next_cursor": None, "request_id": request.state.request_id}}
