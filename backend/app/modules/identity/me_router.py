from fastapi import APIRouter, Depends, Request

from app.core.dependencies import get_current_user
from app.modules.identity.auth_schema import AuthResponse
from app.modules.identity.firebase_auth_service import set_user_role
from app.modules.identity.me_schema import MeResponse
from app.modules.identity.me_service import build_me_response
from app.modules.identity.profile_repository import ProfileRepository

router = APIRouter(prefix="/v1/me", tags=["M1 - Me"])


@router.get("", response_model=MeResponse)
def get_me(request: Request, current_user: dict = Depends(get_current_user)):
    """
    V3 contract: GET /me (ST02, A08). Auth: Bearer. Identity sirf token se.
    Email/phone masked aate hain, poore kabhi nahi.
    """
    user_id = current_user["user_id"]
    profile = ProfileRepository.get_by_user_id(user_id)
    sportsz_doc = ProfileRepository.get_sportsz_id(user_id)
    return build_me_response(
        current_user,
        profile,
        sportsz_doc,
        getattr(request.state, "request_id", None),
    )


@router.post("/roles/athlete", response_model=AuthResponse)
def enroll_as_athlete(current_user: dict = Depends(get_current_user)):
    """
    V3 contract: POST /me/roles/athlete (O01). Auth: Bearer. No request body —
    user id/role kabhi client se nahi aate, sirf token se.
    """
    return set_user_role(current_user["user_id"], "athlete")