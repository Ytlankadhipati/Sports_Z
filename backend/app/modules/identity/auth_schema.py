from pydantic import BaseModel
from typing import Literal, Optional

RoleType = Literal["athlete", "coach", "institute", "recruiter", "admin"]


class FirebaseTokenRequest(BaseModel):
    id_token: str


class RoleSelectionRequest(BaseModel):
    user_id: str
    role: RoleType


class AuthResponse(BaseModel):
    token: str
    user_id: str
    role: Optional[str] = None