from fastapi import APIRouter, Depends, Request

from app.core.dependencies import get_current_athlete
from app.core.response import success_response
from app.modules.identity.sportsz_id_service import SportsZIdService


router = APIRouter(prefix="/v1/me/sportsz-id", tags=["M1 - SportsZ ID"])
service = SportsZIdService()


@router.get("")
def get_my_sportsz_id(
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    identity = service.get_my_identity(current_user["user_id"])
    return success_response(
        identity.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )
