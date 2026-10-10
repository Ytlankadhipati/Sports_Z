"""Pure helpers for GET /v1/me. No database or Firebase calls here, so they are
easy to unit test. The router does the lookups and passes the results in."""

from typing import Any, Optional

from app.modules.identity.me_schema import MeData, MeMeta, MeResponse

DOT = "\u2022"


def mask_email(email: Optional[str]) -> Optional[str]:
    """ravi.kumar@example.com -> r•••@example.com"""
    if not email or "@" not in email:
        return None
    local, _, domain = email.rpartition("@")
    if not local or not domain:
        return None
    return f"{local[0]}{DOT * 3}@{domain}"


def mask_phone(phone: Optional[str]) -> Optional[str]:
    """+919876543210 -> +91 98••• ••210  (never returns the full number)"""
    if not phone:
        return None
    digits = "".join(ch for ch in phone if ch.isdigit())
    if len(digits) < 6:
        return None
    last3 = digits[-3:]
    if len(digits) >= 10:
        national = digits[-10:]
        country = digits[:-10]
        prefix = f"+{country} " if country else ""
        return f"{prefix}{national[:2]}{DOT * 3} {DOT * 2}{last3}"
    return f"{DOT * 4}{last3}"


def build_me_response(
    current_user: dict[str, Any],
    profile: Optional[dict[str, Any]],
    sportsz_doc: Optional[dict[str, Any]],
    request_id: Optional[str],
) -> MeResponse:
    claims = current_user.get("claims") or {}
    role = current_user.get("role")
    phone_number = claims.get("phone_number")

    data = MeData(
        user_id=current_user["user_id"],
        full_name=(profile or {}).get("full_name"),
        account_label="SportsZ athlete account" if role == "athlete" else "SportsZ account",
        email_masked=mask_email(claims.get("email")),
        email_verified=bool(claims.get("email_verified")),
        phone_masked=mask_phone(phone_number),
        # Firebase only attaches phone_number after OTP verification
        phone_verified=bool(phone_number),
        linked_providers=list(claims.get("providers") or []),
        roles=[role] if role else [],
        sportsz_id=(sportsz_doc or {}).get("sportsz_id"),
    )
    return MeResponse(data=data, meta=MeMeta(request_id=request_id))