"""platform_config: tunable limits stored in Mongo with safe code defaults.

Collection `platform_config`, one document per section, e.g.
  {"_id": "limits", "values": {"message_max_chars": 1000}}
If the DB has no value, the default below is used, so the app never breaks
on an empty database. Reads are cached for a short TTL.
"""

from __future__ import annotations

import time
from typing import Any

DEFAULTS: dict[str, dict[str, Any]] = {
    "limits": {
        "message_max_chars": 1000,
        "connection_note_max_chars": 140,
        "message_rate_per_minute": 20,
        "connection_requests_per_day": 30,
        "grant_default_days": 90,
    },
}


class PlatformConfigService:
    def __init__(self, collection=None, ttl_seconds: float = 30.0, clock=time.monotonic):
        self._collection = collection
        self._ttl = ttl_seconds
        self._clock = clock
        self._cache: dict[str, tuple[float, dict[str, Any]]] = {}

    def _section(self, name: str) -> dict[str, Any]:
        now = self._clock()
        hit = self._cache.get(name)
        if hit and now - hit[0] < self._ttl:
            return hit[1]
        values = dict(DEFAULTS.get(name, {}))
        if self._collection is not None:
            doc = self._collection.find_one({"_id": name})
            if doc and isinstance(doc.get("values"), dict):
                values.update(doc["values"])
        self._cache[name] = (now, values)
        return values

    def get(self, path: str, default: Any = None) -> Any:
        """get("limits.message_max_chars")"""
        section, _, key = path.partition(".")
        return self._section(section).get(key, default)

    def get_int(self, path: str, default: int) -> int:
        try:
            return int(self.get(path, default))
        except (TypeError, ValueError):
            return default

    def seed_defaults(self) -> None:
        """Insert missing sections (idempotent). Used by the seed CLI."""
        if self._collection is None:
            return
        for name, values in DEFAULTS.items():
            self._collection.update_one(
                {"_id": name}, {"$setOnInsert": {"values": values}}, upsert=True
            )

    def clear_cache(self) -> None:
        self._cache.clear()
