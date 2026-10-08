from fastapi import APIRouter, Request

from app.core.errors import not_found
from app.core.response import success_response
from app.modules.identity.profile_repository import ProfileRepository


router = APIRouter(prefix="/v1/sports", tags=["M1 - Sports Catalog"])
repository = ProfileRepository()


@router.get("")
def list_sports(request: Request):
    return success_response(
        {"sports": repository.list_sports()},
        request_id=getattr(request.state, "request_id", None),
    )


@router.get("/{sport_id}/config")
def get_sport_config(sport_id: str, request: Request):
    sport = repository.get_sport_config(sport_id)
    if not sport or not isinstance(sport.get("config"), dict):
        raise not_found("Sport configuration was not found")
    return success_response(
        {"sport": sport},
        request_id=getattr(request.state, "request_id", None),
    )
