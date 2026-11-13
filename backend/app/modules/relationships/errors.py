"""Domain errors for M4 services. Routers translate them to M1-style HTTP errors."""

from __future__ import annotations

from fastapi import HTTPException


class DomainError(Exception):
    status_code = 400
    code = "BAD_REQUEST"

    def __init__(self, message: str = "", details: list | None = None):
        super().__init__(message or self.code)
        self.message = message or self.code
        self.details = details or []


class NotFoundError(DomainError):
    """Also used for HIDDEN resources: must look identical to a missing id."""
    status_code = 404
    code = "NOT_FOUND"

    def __init__(self, message: str = "Resource not found"):
        super().__init__(message)


class ForbiddenError(DomainError):
    status_code = 403
    code = "FORBIDDEN"

    def __init__(self, message: str = "You are not authorized to perform this action"):
        super().__init__(message)


class ConflictError(DomainError):
    status_code = 409
    code = "CONFLICT"


class ValidationFailed(DomainError):
    status_code = 422
    code = "VALIDATION_ERROR"


class RateLimited(DomainError):
    status_code = 429
    code = "RATE_LIMITED"

    def __init__(self, retry_after: int = 60):
        super().__init__("Too many requests")
        self.retry_after = retry_after


def to_http(exc: DomainError) -> HTTPException:
    headers = {"Retry-After": str(exc.retry_after)} if isinstance(exc, RateLimited) else None
    return HTTPException(
        status_code=exc.status_code,
        detail={"code": exc.code, "message": exc.message, "details": exc.details},
        headers=headers,
    )
