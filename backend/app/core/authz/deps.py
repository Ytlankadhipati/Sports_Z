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
    # Resolve platform_blocked and verification from current_user or MongoDB
    platform_blocked = bool(current_user.get("platform_blocked") or current_user.get("is_blocked"))
    verification_status = current_user.get("verification_status")

    if "platform_blocked" not in current_user or "verification_status" not in current_user:
        try:
            from app.core.database import users_collection
            from bson import ObjectId

            u_doc = None
            uid = current_user.get("user_id")
            if uid:
                try:
                    u_doc = users_collection.find_one({"_id": ObjectId(uid)})
                except Exception:
                    u_doc = users_collection.find_one({"_id": uid})
            elif current_user.get("firebase_uid"):
                u_doc = users_collection.find_one({"firebase_uid": current_user["firebase_uid"]})

            if u_doc:
                platform_blocked = bool(u_doc.get("platform_blocked") or u_doc.get("is_blocked"))
                verification_status = u_doc.get("verification_status")
        except Exception:
            pass

    is_verified = (verification_status == "verified")
    verification = {
        "coach": is_verified,
        "recruiter": is_verified,
    }

    try:
        return build_viewer_context(
            current_user,
            x_active_role,
            verification=verification,
            is_blocked_user=platform_blocked,
        )
    except InvalidActiveRole:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "FORBIDDEN",
                "message": "You are not authorized to perform this action",
                "details": [],
            },
        )
