from datetime import date
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class PhysicalStats(BaseModel):
    model_config = ConfigDict(extra="forbid")

    height_cm: float | None = Field(default=None, ge=30, le=300)
    weight_kg: float | None = Field(default=None, ge=1, le=500)
    dominant_hand: str | None = None
    measured_at: date | None = None


class SportProfile(BaseModel):
    model_config = ConfigDict(extra="forbid")

    sport_id: str
    sport_name: str | None = None
    is_primary: bool = False
    positions: list[str] = Field(default_factory=list)
    level: str | None = None
    attributes: dict[str, Any] = Field(default_factory=dict)


class ExperienceItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    title: str
    organization_id: str | None = None
    organization_name: str | None = None
    started_year: int | None = Field(default=None, ge=1900, le=2100)
    ended_year: int | None = Field(default=None, ge=1900, le=2100)
    description: str | None = None


class PrivacySettings(BaseModel):
    model_config = ConfigDict(extra="forbid")

    discoverable: bool = True
    contact_policy: str | None = None
    field_overrides: dict[str, Any] = Field(default_factory=dict)


class AthleteSportInput(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    sport_id: str | None = Field(default=None, min_length=1, max_length=80)
    sport_name: str = Field(min_length=1, max_length=80)
    positions: list[str] = Field(default_factory=list, max_length=20)
    level: str | None = Field(default=None, max_length=80)


class AthleteOnboardingProfileInput(BaseModel):
    """Client-editable M1 fields submitted at athlete onboarding completion."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    full_name: str = Field(min_length=1, max_length=120)
    date_of_birth: date
    gender: str = Field(min_length=1, max_length=40)
    photo_url: str | None = Field(default=None, max_length=2048)
    sports: list[AthleteSportInput] = Field(min_length=1, max_length=10)


class AthleteProfilePatch(BaseModel):
    """Sparse client-editable fields used by resumable onboarding."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    date_of_birth: date | None = None
    gender: str | None = Field(default=None, min_length=1, max_length=40)
    photo_url: str | None = Field(default=None, max_length=2048)
    city: str | None = Field(default=None, max_length=120)
    region: str | None = Field(default=None, max_length=120)
    bio: str | None = Field(default=None, max_length=500)
    sports: list[AthleteSportInput] | None = Field(default=None, max_length=10)
    physical: PhysicalStats | None = None
    privacy: PrivacySettings | None = None


class AthleteProfileResponse(BaseModel):
    """
    M1-owned profile projection for the authenticated athlete.

    Server-owned fields are response-only and are never accepted
    through a profile update request.
    """

    model_config = ConfigDict(extra="forbid")

    user_id: str
    sportsz_id: str | None = None

    full_name: str | None = None
    date_of_birth: date | None = None
    gender: str | None = None

    city: str | None = None
    region: str | None = None

    bio: str | None = Field(default=None, max_length=500)

    photo_url: str | None = None
    cover_photo_url: str | None = Field(
        default=None,
        description="Unsupported on backend M1 schema; reserved for M5 media integration TODO",
    )

    sports: list[SportProfile] = Field(default_factory=list)

    physical: PhysicalStats | None = None

    experience: list[ExperienceItem] = Field(default_factory=list)

    privacy: PrivacySettings | None = None

    completion: int = Field(default=0, ge=0, le=100)
