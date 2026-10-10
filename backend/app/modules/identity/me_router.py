from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user
from app.modules.identity.auth_schema import AuthResponse
from app.modules.identity.firebase_auth_service import set_user_role

router = APIRouter(prefix="/v1/me", tags=["M1 - Me"])


@router.post("/roles/athlete", response_model=AuthResponse)
def enroll_as_athlete(current_user: dict = Depends(get_current_user)):
    """
    V3 contract: POST /me/roles/athlete (O01). Auth: Bearer. No request body —
    user id/role kabhi client se nahi aate, sirf token se.
    """
    return set_user_role(current_user["user_id"], "athlete")
