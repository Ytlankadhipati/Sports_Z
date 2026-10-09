from fastapi import APIRouter, Depends, Request

from app.core.dependencies import get_current_athlete
from app.core.response import success_response
from app.modules.identity.profile_repository import ProfileRepository


router = APIRouter(prefix="/v1/organizations", tags=["M1 - Organizations"])
repository = ProfileRepository()


@router.get("")
def list_organizations(
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    return success_response(
        {"organizations": repository.list_organizations()},
        request_id=getattr(request.state, "request_id", None),
    )
