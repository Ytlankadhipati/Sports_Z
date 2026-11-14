"""ViewerContext: who is making this request, and in which role.

Pure (no DB, no Firebase) so it is trivial to unit test. The FastAPI
dependency that builds it from the M1 `get_current_user` result lives in
`deps.py`, so importing this module never needs Firebase credentials.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

VALID_ROLES = frozenset({"athlete", "coach", "recruiter", "org", "admin"})


class InvalidActiveRole(Exception):
    """X-Active-Role asked for a role the user does not hold."""


@dataclass(frozen=True)
class ViewerContext:
    user_id: str
    roles: frozenset[str]
    active_role: str | None
    is_blocked_user: bool = False  # platform-level block (USER_BLOCKED fixture)
    coach_verified: bool = False
    recruiter_verified: bool = False

    @property
    def is_admin(self) -> bool:
        return self.active_role == "admin"

    def is_verified(self, role: str | None = None) -> bool:
        role = role or self.active_role
        if role == "coach":
            return self.coach_verified
        if role == "recruiter":
            return self.recruiter_verified
        return role in {"athlete", "admin", "org"}


def _normalize_roles(user: dict[str, Any]) -> frozenset[str]:
    """M1 stores a single string `role`; the v3 doc talks about `roles` (list).
    Accept both so we do not break when M1 moves to a list."""
    raw: Iterable[str] = []
    if isinstance(user.get("roles"), (list, tuple, set, frozenset)):
        raw = user["roles"]
    elif user.get("role"):
        raw = [user["role"]]
    return frozenset(r for r in raw if r in VALID_ROLES)


def build_viewer_context(
    user: dict[str, Any],
    active_role_header: str | None = None,
    *,
    verification: dict[str, bool] | None = None,
    is_blocked_user: bool = False,
) -> ViewerContext:
    """`user` is the dict returned by M1's get_current_user:
    {user_id, firebase_uid, role, claims}.

    The active role comes from the X-Active-Role header, but ONLY if the
    user really holds that role. Without a header: the single held role,
    otherwise None (caller must ask the client to choose).
    """
    roles = _normalize_roles(user)
    header = (active_role_header or "").strip().lower() or None

    if header is not None:
        if header not in roles:
            raise InvalidActiveRole(header)
        active = header
    elif len(roles) == 1:
        active = next(iter(roles))
    else:
        active = None

    v = verification or {}
    return ViewerContext(
        user_id=user["user_id"],
        roles=roles,
        active_role=active,
        is_blocked_user=is_blocked_user,
        coach_verified=bool(v.get("coach")),
        recruiter_verified=bool(v.get("recruiter")),
    )
