from pydantic import BaseModel, ConfigDict
from typing import Literal, Optional

RoleType = Literal["athlete", "coach", "institute", "recruiter"]


class FirebaseTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_token: str


class RoleSelectionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: RoleType


class AuthResponse(BaseModel):
    token: str
    user_id: str
    role: Optional[str] = None
