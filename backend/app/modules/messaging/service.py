"""Messaging service (M01-M05)."""

from __future__ import annotations

from typing import Any, Callable, Protocol

from app.core.authz import ViewerContext
from app.core.platform_config import PlatformConfigService
from app.core.ratelimit import RateLimitExceeded, RateLimiter
from app.modules.messaging.repository import ConversationRepository, MessageRepository
from app.modules.messaging.rules import Facts, Party, can_send_message, can_start_conversation
from app.modules.relationships.errors import ForbiddenError, NotFoundError, RateLimited, ValidationFailed
from app.modules.relationships.repository import utcnow
from app.modules.relationships.service import RelationshipResolver, UserDirectory, iso


class ApplicationLookup(Protocol):
    """M3 provides this. True if `athlete_id` has an application to an opportunity
    owned by `recruiter_id`."""

    def __call__(self, athlete_id: str, recruiter_id: str) -> bool: ...


def no_applications(_athlete_id: str, _recruiter_id: str) -> bool:
    """TODO(M3): replace with the real applications lookup. Safe default = False."""
    return False


class MessagingService:
    def __init__(self, conversations: ConversationRepository, messages: MessageRepository,
                 directory: UserDirectory, resolver: RelationshipResolver,
                 config: PlatformConfigService, limiter: RateLimiter,
                 has_application: ApplicationLookup = no_applications, now: Callable = utcnow):
        self.convs, self.msgs, self.directory, self.resolver = conversations, messages, directory, resolver
        self.config, self.limiter, self.has_application, self._now = config, limiter, has_application, now

    # ---------- helpers ----------
    def _party(self, user_id: str, role: str | None = None, verified: bool | None = None) -> Party:
        u = self.directory.get(user_id) or {}
        return Party(user_id, role or u.get("role"), bool(u.get("verified") if verified is None else verified))

    def _viewer_party(self, viewer: ViewerContext) -> Party:
        return Party(viewer.user_id, viewer.active_role, viewer.is_verified())

    def facts(self, a: Party, b: Party) -> Facts:
        r = self.resolver
        athlete, pro = (a, b) if a.role == "athlete" else (b, a)
        return Facts(
            blocked=r.is_blocked(a.user_id, b.user_id),
            connection_accepted=r.connection_accepted(a.user_id, b.user_id),
            active_coach_link=pro.role == "coach" and athlete.role == "athlete"
            and r.active_link(pro.user_id, athlete.user_id),
            has_application=pro.role == "recruiter" and athlete.role == "athlete"
            and bool(self.has_application(athlete.user_id, pro.user_id)),
        )

    def _participant_conv(self, viewer: ViewerContext, conv_id: str) -> dict[str, Any]:
        conv = self.convs.get(conv_id)
        if conv is None or viewer.user_id not in conv["participants"]:
            raise NotFoundError()  # IDOR safe
        return conv

    def _writable(self, viewer: ViewerContext, conv: dict[str, Any]) -> tuple[bool, str]:
        other_id = next(p for p in conv["participants"] if p != viewer.user_id)
        me, other = self._viewer_party(viewer), self._party(other_id)
        v = can_send_message(me, other, self.facts(me, other))
        return v.ok, v.reason

    def _conv_view(self, viewer: ViewerContext, conv: dict[str, Any]) -> dict[str, Any]:
        other_id = next(p for p in conv["participants"] if p != viewer.user_id)
        other = self.directory.get(other_id) or {}
        writable, reason = self._writable(viewer, conv)
        unread = self.msgs.count_unread(conv["id"], viewer.user_id, conv.get("last_read", {}).get(viewer.user_id))
        return {
            "id": conv["id"],
            "counterpart": {"user_id": other_id, "name": other.get("name"),
                            "photo_url": other.get("photo_url"), "role": other.get("role")},
            "last_message_preview": conv.get("last_message_preview"),
            "last_message_at": iso(conv.get("last_message_at")),
            "unread_count": unread,
            "muted": viewer.user_id in conv.get("muted_by", []),
            "read_only": not writable,
            "read_only_reason": None if writable else reason,
        }

    def _msg_view(self, viewer: ViewerContext, m: dict[str, Any]) -> dict[str, Any]:
        return {"id": m["id"], "conversation_id": m["conversation_id"], "text": m["text"],
                "sender_is_me": m["sender_id"] == viewer.user_id, "created_at": iso(m["created_at"])}

    def _check_text(self, text: str) -> str:
        text = (text or "").strip()
        limit = self.config.get_int("limits.message_max_chars", 1000)
        if not text:
            raise ValidationFailed("Message cannot be empty")
        if len(text) > limit:
            raise ValidationFailed(f"Message must be at most {limit} characters")
        return text

    def _rate(self, viewer: ViewerContext) -> None:
        try:
            self.limiter.check(f"msg:{viewer.user_id}",
                               self.config.get_int("limits.message_rate_per_minute", 20), 60)
        except RateLimitExceeded as e:
            raise RateLimited(e.retry_after)

    def _guard(self, viewer: ViewerContext) -> None:
        if viewer.active_role not in ("athlete", "coach", "recruiter") or viewer.is_blocked_user:
            raise ForbiddenError()

    # ---------- M01 / M02 ----------
    def list_conversations(self, viewer: ViewerContext, limit: int, after_id: str | None, q: str | None = None):
        self._guard(viewer)
        docs = self.convs.list_for_user(viewer.user_id, limit + 1, after_id)
        nxt = docs[limit - 1]["id"] if len(docs) > limit else None
        views = [self._conv_view(viewer, d) for d in docs[:limit]]
        if q:  # M02 search: filter, no new API
            needle = q.strip().lower()
            views = [v for v in views if needle in (v["counterpart"]["name"] or "").lower()
                     or needle in (v["last_message_preview"] or "").lower()]
        return views, nxt

    # ---------- M05 ----------
    def start(self, viewer: ViewerContext, other_id: str, text: str) -> dict[str, Any]:
        self._guard(viewer)
        text = self._check_text(text)
        other_u = self.directory.get(other_id)
        if other_u is None:
            raise NotFoundError()
        me, other = self._viewer_party(viewer), self._party(other_id)
        facts = self.facts(me, other)
        if facts.blocked:
            raise NotFoundError()  # blocked is invisible to the other side
        existing = self.convs.get_by_pair(viewer.user_id, other_id)
        if existing:
            return self.send(viewer, existing["id"], text, _conv=existing)
        verdict = can_start_conversation(me, other, facts)
        if not verdict.ok:
            if verdict.reason in ("self", "pair_not_allowed"):
                raise NotFoundError()
            raise ForbiddenError("You cannot message this person yet")
        self._rate(viewer)
        conv = self.convs.insert(viewer.user_id, other_id, verdict.basis)
        return self._post(viewer, conv, text)

    # ---------- M03 ----------
    def send(self, viewer: ViewerContext, conv_id: str, text: str, _conv: dict[str, Any] | None = None):
        self._guard(viewer)
        text = self._check_text(text)
        conv = _conv or self._participant_conv(viewer, conv_id)
        writable, reason = self._writable(viewer, conv)
        if not writable:
            if reason == "blocked":
                raise NotFoundError()
            raise ForbiddenError("This conversation is read-only")
        self._rate(viewer)
        return self._post(viewer, conv, text)

    def _post(self, viewer: ViewerContext, conv: dict[str, Any], text: str) -> dict[str, Any]:
        m = self.msgs.insert(conv["id"], viewer.user_id, text)
        self.convs.touch(conv["id"], text, m["created_at"])
        self.convs.unhide_for_all(conv["id"])  # a new message re-opens a deleted thread
        return {"conversation_id": conv["id"], "message": self._msg_view(viewer, m)}

    def list_messages(self, viewer: ViewerContext, conv_id: str, limit: int, after_id: str | None):
        self._guard(viewer)
        conv = self._participant_conv(viewer, conv_id)
        docs = self.msgs.list(conv_id, limit + 1, after_id)
        nxt = docs[limit - 1]["id"] if len(docs) > limit else None
        return {"conversation": self._conv_view(viewer, conv),
                "messages": [self._msg_view(viewer, d) for d in docs[:limit]]}, nxt

    # ---------- M04 ----------
    def mark_read(self, viewer: ViewerContext, conv_id: str) -> None:
        self._participant_conv(viewer, conv_id)
        self.convs.mark_read(conv_id, viewer.user_id, self._now())

    def set_mute(self, viewer: ViewerContext, conv_id: str, muted: bool) -> dict[str, Any]:
        conv = self._participant_conv(viewer, conv_id)
        self.convs.set_membership(conv_id, "muted_by", viewer.user_id, muted)
        return self._conv_view(viewer, self.convs.get(conv["id"]))

    def delete_for_me(self, viewer: ViewerContext, conv_id: str) -> None:
        self._participant_conv(viewer, conv_id)
        self.convs.set_membership(conv_id, "hidden_by", viewer.user_id, True)
