"""Mongo access for conversations and messages (M4 owns both)."""

from __future__ import annotations

from typing import Any

from app.modules.relationships.repository import _Base, out, pair_key, to_oid, utcnow


class ConversationRepository(_Base):
    def get_by_pair(self, a: str, b: str) -> dict[str, Any] | None:
        return out(self.c.find_one({"pair_key": pair_key(a, b)}))

    def insert(self, starter_id: str, other_id: str, basis: str) -> dict[str, Any]:
        return self._insert({
            "pair_key": pair_key(starter_id, other_id),
            "participants": [starter_id, other_id],
            "started_by": starter_id,
            "basis": basis,
            "muted_by": [],
            "hidden_by": [],          # DELETE /conversations/{id} hides it for ONE side only
            "last_message_at": None,
            "last_message_preview": None,
            "last_read": {},          # user_id -> datetime (private; no read receipts exposed)
        })

    def list_for_user(self, user_id: str, limit: int, after_id: str | None):
        q = {"participants": user_id, "hidden_by": {"$ne": user_id}}
        return self._page(q, limit, after_id)

    def touch(self, conv_id: str, preview: str, when) -> None:
        self.update(conv_id, {"last_message_at": when, "last_message_preview": preview[:80]})

    def set_membership(self, conv_id: str, field: str, user_id: str, on: bool) -> None:
        op = "$addToSet" if on else "$pull"
        self.c.update_one({"_id": to_oid(conv_id)}, {op: {field: user_id}, "$set": {"updated_at": utcnow()}})

    def mark_read(self, conv_id: str, user_id: str, when) -> None:
        self.c.update_one({"_id": to_oid(conv_id)}, {"$set": {f"last_read.{user_id}": when}})

    def unhide_for_all(self, conv_id: str) -> None:
        self.c.update_one({"_id": to_oid(conv_id)}, {"$set": {"hidden_by": []}})

    def ensure_indexes(self) -> None:
        self.c.create_index([("pair_key", 1)], unique=True, name="uq_conversations_pair")
        self.c.create_index([("participants", 1), ("last_message_at", -1)], name="ix_conversations_participant")


class MessageRepository(_Base):
    def insert(self, conv_id: str, sender_id: str, text: str) -> dict[str, Any]:
        return self._insert({"conversation_id": conv_id, "sender_id": sender_id, "text": text})

    def list(self, conv_id: str, limit: int, after_id: str | None):
        return self._page({"conversation_id": conv_id}, limit, after_id)

    def count_unread(self, conv_id: str, user_id: str, since) -> int:
        q: dict[str, Any] = {"conversation_id": conv_id, "sender_id": {"$ne": user_id}}
        if since:
            q["created_at"] = {"$gt": since}
        return self.c.count_documents(q)

    def ensure_indexes(self) -> None:
        self.c.create_index([("conversation_id", 1), ("_id", -1)], name="ix_messages_conv")
