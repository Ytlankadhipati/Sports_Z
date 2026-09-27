from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.security import decode_access_token

# Ye batata hai FastAPI ko ki token kahan se milega (login endpoint se)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """
    Har protected route isse use karega.
    Request header me 'Authorization: Bearer <token>' se token nikalta hai,
    verify karta hai, aur user info (payload) return karta hai.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    user_id = payload.get("sub")
    role = payload.get("role")

    if user_id is None or role is None:
        raise credentials_exception

    return {"user_id": user_id, "role": role}


def require_role(*allowed_roles: str):
    """
    RBAC ke liye — sirf specific roles ko route access karne dega.
    Example use: @app.get("/admin/dashboard", dependencies=[Depends(require_role("admin"))])
    """
    def role_checker(current_user: dict = Depends(get_current_user)) -> dict:
        if current_user["role"] not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{current_user['role']}' is not authorized for this action",
            )
        return current_user

    return role_checker