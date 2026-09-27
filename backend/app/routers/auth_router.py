from fastapi import APIRouter
from app.schemas.auth_schema import SignupRequest, LoginRequest, AuthResponse
from app.services.firebase_auth_service import signup_user, login_user

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/signup", response_model=AuthResponse, status_code=201)
def signup(request: SignupRequest):
    result = signup_user(request.email, request.password, request.role)
    return result


@router.post("/login", response_model=AuthResponse)
def login(request: LoginRequest):
    result = login_user(request.email, request.password)
    return result