from fastapi import APIRouter, Request

from app.core.response import success_response
from app.modules.identity.public_id_service import PublicIdService

# I04: public SportsZ ID page. No authentication on purpose (contract 5).
router = APIRouter(prefix="/v1/id", tags=["M1 - Public ID"])
service = PublicIdService()


@router.get("/{sportsz_id}")
def get_public_id(sportsz_id: str, request: Request):
    data = service.get_public_id(sportsz_id)
    return success_response(
        data.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )
