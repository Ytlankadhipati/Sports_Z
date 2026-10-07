from fastapi import APIRouter, Depends
from app.core.dependencies import get_current_user
from app.modules.identity.auth_schema import FirebaseTokenRequest, RoleSelectionRequest, AuthResponse
from app.modules.identity.firebase_auth_service import verify_firebase_token, set_user_role

router = APIRouter(prefix="/v1/auth", tags=["Auth"])


@router.post("/verify", response_model=AuthResponse)
def verify_token(request: FirebaseTokenRequest):
    """
    Flutter app Firebase se login/signup karne ke baad ye endpoint call karega,
    Firebase ID token bhej ke — backend apna JWT wapas dega.
    """
    result = verify_firebase_token(request.id_token)
    return result


@router.post("/select-role", response_model=AuthResponse)
def select_role(
    request: RoleSelectionRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Naye user ke liye role set karta hai (role_selection_screen.dart se call hoga).
    """
    result = set_user_role(current_user["user_id"], request.role)
    return result
