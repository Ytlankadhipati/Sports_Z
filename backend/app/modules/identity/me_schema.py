from typing import Optional

from pydantic import BaseModel, ConfigDict


class MeData(BaseModel):
    """GET /v1/me payload (contract: docs/api/m1.yaml, contract 1)."""

    model_config = ConfigDict(extra="forbid")

    user_id: str
    full_name: Optional[str] = None
    account_label: str
    email_masked: Optional[str] = None
    email_verified: bool = False
    phone_masked: Optional[str] = None
    phone_verified: bool = False
    # Firebase identity keys that are linked, e.g. ["email", "google.com", "phone"]
    linked_providers: list[str] = []
    roles: list[str] = []
    sportsz_id: Optional[str] = None


class MeMeta(BaseModel):
    request_id: Optional[str] = None


class MeResponse(BaseModel):
    data: MeData
    meta: MeMeta