from pydantic import BaseModel, EmailStr, Field
from typing import Literal

# Roles jo doc me define hain
RoleType = Literal["athlete", "coach", "institute", "recruiter", "admin"]


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)
    role: RoleType


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    token: str
    user_id: str
    role: str