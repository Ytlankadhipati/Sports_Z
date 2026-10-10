from fastapi import APIRouter, Depends, Response, status

from app.core.dependencies import get_current_user
from app.modules.identity.auth_schema import FirebaseTokenRequest, RoleSelectionRequest, AuthResponse
from app.modules.identity.firebase_auth_service import verify_firebase_token, set_user_role

router = APIRouter(prefix="/v1/auth", tags=["Auth"])


@router.post("/session", response_model=AuthResponse)
def create_session(request: FirebaseTokenRequest):
    """
    V3 contract: POST /auth/session (A01, A03, A04, A05, A07).

    Flutter Firebase se login/signup/session-restore ke baad Firebase ID token
    bhejta hai — backend user find/create karke apna JWT wapas deta hai.
    """
    return verify_firebase_token(request.id_token)


@router.post(
    "/verify",
    response_model=AuthResponse,
    deprecated=True,
    summary="Deprecated alias of POST /auth/session",
)
def verify_token(request: FirebaseTokenRequest):
    """
    DEPRECATED: purana naam, sirf transition ke liye (jin branches/builds ne
    abhi /auth/verify call kiya hai). POST /auth/session use karo.
    TODO: sab members ke migrate hone ke baad hata do.
    """
    return verify_firebase_token(request.id_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(current_user: dict = Depends(get_current_user)) -> Response:
    """
    V3 contract: POST /auth/logout (A07, X01). Auth: Bearer.

    Abhi backend stateless hai (server-side session store nahi hai), isliye ye
    authenticated, idempotent acknowledgement hai. Client Firebase signOut +
    local session clear khud karta hai.
    TODO: AuditService.append (M2) aur logout-all-devices (ST03, V3 Open item 3)
    jab unke contracts decide ho jayein.
    """
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/select-role", response_model=AuthResponse)
def select_role(
    request: RoleSelectionRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Existing generic role-selection (coach/institute/recruiter ke liye abhi bhi
    yahi). Athlete ke liye V3 route POST /me/roles/athlete hai.
    """
    return set_user_role(current_user["user_id"], request.role)
