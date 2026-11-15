from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class SportsZIdentityResponse(BaseModel):
    """Publicly safe identity-card projection for the signed-in athlete."""

    model_config = ConfigDict(extra="forbid")

    sportsz_id: str
    full_name: str | None = None
    photo_url: str | None = None
    primary_sport: str | None = None
    positions: list[str] = Field(default_factory=list)
    level: str | None = None
    qr_token: str | None = None
    qr_rotated_at: datetime | None = None


class QrRotateResponse(BaseModel):
    """Result of POST /v1/me/sportsz-id/rotate-qr (owner only)."""

    model_config = ConfigDict(extra="forbid")

    sportsz_id: str
    qr_token: str
    qr_rotated_at: datetime
