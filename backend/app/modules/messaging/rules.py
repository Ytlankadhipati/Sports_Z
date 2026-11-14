"""ADR-001 messaging rules as ONE pure function (no DB).

  * 1-to-1, text only, Phase 1.
  * Athlete <-> verified coach: accepted connection OR active coach link.
  * Athlete <-> verified recruiter: accepted connection OR an application to
    that recruiter's opportunity (M3 lookup).
  * Unverified coach/recruiter cannot START a conversation (may reply).
  * Blocked, or no valid basis any more -> read-only.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Party:
    user_id: str
    role: str | None
    verified: bool = False


@dataclass(frozen=True)
class Facts:
    blocked: bool = False
    connection_accepted: bool = False
    active_coach_link: bool = False
    has_application: bool = False   # athlete applied to this recruiter's opportunity


@dataclass(frozen=True)
class Verdict:
    ok: bool
    basis: str | None = None        # connection | link | application
    reason: str = ""                # internal / UI hint


def _basis(athlete_side: Party, pro: Party, facts: Facts) -> str | None:
    if pro.role == "coach":
        if facts.active_coach_link:
            return "link"
        if facts.connection_accepted:
            return "connection"
    elif pro.role == "recruiter":
        if facts.connection_accepted:
            return "connection"
        if facts.has_application:
            return "application"
    return None


def _split(a: Party, b: Party) -> tuple[Party, Party] | None:
    """-> (athlete, professional) or None when the pair is not allowed in Phase 1."""
    for ath, pro in ((a, b), (b, a)):
        if ath.role == "athlete" and pro.role in ("coach", "recruiter"):
            return ath, pro
    return None


def can_start_conversation(starter: Party, other: Party, facts: Facts) -> Verdict:
    if starter.user_id == other.user_id:
        return Verdict(False, reason="self")
    if facts.blocked:
        return Verdict(False, reason="blocked")
    pair = _split(starter, other)
    if pair is None:
        return Verdict(False, reason="pair_not_allowed")
    athlete, pro = pair
    if not pro.verified:
        return Verdict(False, reason="professional_unverified")
    basis = _basis(athlete, pro, facts)
    if basis is None:
        return Verdict(False, reason="no_basis")
    return Verdict(True, basis=basis)


def can_send_message(sender: Party, other: Party, facts: Facts) -> Verdict:
    """Existing conversation. Replies are allowed even if the professional lost
    verification; they are NOT allowed once blocked or the basis is gone."""
    if facts.blocked:
        return Verdict(False, reason="blocked")
    pair = _split(sender, other)
    if pair is None:
        return Verdict(False, reason="pair_not_allowed")
    athlete, pro = pair
    basis = _basis(athlete, pro, facts)
    if basis is None:
        return Verdict(False, reason="basis_ended")
    return Verdict(True, basis=basis)
