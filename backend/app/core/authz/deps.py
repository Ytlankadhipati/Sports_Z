"""FastAPI glue. Imported by routers only (needs M1's Firebase setup)."""

from fastapi import Depends, Header, HTTPException, status

from app.core.authz.viewer_context import (
    InvalidActiveRole,
    ViewerContext,
    build_viewer_context,
)
from app.core.dependencies import get_current_user


def get_viewer_context(
    current_user: dict = Depends(get_current_user),
    x_active_role: str | None = Header(default=None, alias="X-Active-Role"),
) -> ViewerContext:
    # TODO(M4/M5): fill `verification` from M5's verification state
    try:
        return build_viewer_context(current_user, x_active_role)
    except InvalidActiveRole:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "FORBIDDEN",
                "message": "You are not authorized to perform this action",
                "details": [],
            },
        )
