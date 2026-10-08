from typing import Any


def success_response(
    data: Any,
    *,
    request_id: str | None = None,
    next_cursor: str | None = None,
) -> dict:
    return {
        "data": data,
        "meta": {
            "next_cursor": next_cursor,
            "request_id": request_id,
        },
    }