from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.errors import forbidden, unauthorized
from app.modules.identity.firebase_auth_service import (
    resolve_firebase_user,
)


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        bearer_scheme
    ),
) -> dict:

    if credentials is None:
        raise unauthorized()

    if credentials.scheme.lower() != "bearer":
        raise unauthorized()

    token = credentials.credentials

    return resolve_firebase_user(token)


def get_current_athlete(
    current_user: dict = Depends(get_current_user),
) -> dict:

    role = current_user.get("role")

    if role != "athlete":
        raise forbidden(
            "Athlete role is required for this resource"
        )

    return current_user
