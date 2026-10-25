"""Tiny in-process sliding-window rate limiter.

NOTE: per-process memory. Fine for Phase 1 / single instance; swap the
store for Redis when the API runs on several instances (TODO(confirm) with M2).
"""

from __future__ import annotations

import time
from collections import defaultdict, deque


class RateLimitExceeded(Exception):
    def __init__(self, retry_after: int):
        super().__init__("rate limited")
        self.retry_after = retry_after


class RateLimiter:
    def __init__(self, clock=time.monotonic):
        self._clock = clock
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str, limit: int, window_seconds: float) -> None:
        """Record one hit, or raise RateLimitExceeded if over `limit` in the window."""
        now = self._clock()
        q = self._hits[key]
        while q and now - q[0] >= window_seconds:
            q.popleft()
        if len(q) >= limit:
            raise RateLimitExceeded(max(1, int(window_seconds - (now - q[0])) + 1))
        q.append(now)

    def reset(self) -> None:
        self._hits.clear()
