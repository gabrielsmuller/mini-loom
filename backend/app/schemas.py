"""Pydantic schemas — request/response validation and serialization."""
from datetime import datetime
from pydantic import BaseModel, EmailStr


# ---- Auth ----
# No UserCreate/Token anymore: Cognito handles sign-up and issues the tokens.
class UserOut(BaseModel):
    id: str
    email: EmailStr | None = None

    class Config:
        from_attributes = True


# ---- Videos ----
class VideoCreate(BaseModel):
    title: str
    filename: str  # e.g. "meeting.mp4" — used to build the S3 key


class VideoCreateResponse(BaseModel):
    id: str
    upload_url: str            # pre-signed S3 POST endpoint
    upload_fields: dict        # form fields S3 requires (policy, signature, etc.)
    watch_url: str             # the shareable link


class VideoOut(BaseModel):
    id: str
    title: str
    views: int
    created_at: datetime

    class Config:
        from_attributes = True
