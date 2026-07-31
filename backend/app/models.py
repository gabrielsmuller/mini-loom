"""SQLAlchemy models — the shape of the data in Aurora/PostgreSQL."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Integer, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    # The id IS Cognito's `sub` (a stable unique id for the user). We no longer
    # generate our own id, and there's no password column — Cognito holds
    # credentials. We keep a local row so videos can reference an owner.
    id = Column(String, primary_key=True)
    email = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), default=_now)

    videos = relationship("Video", back_populates="owner")


class Video(Base):
    __tablename__ = "videos"

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)  # Cognito sub
    title = Column(String, nullable=False)
    s3_key = Column(String, nullable=False)     # where the video lives in S3
    thumbnail_key = Column(String, nullable=True)  # filled in by Phase 3 worker
    views = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_now)

    owner = relationship("User", back_populates="videos")


class VideoView(Base):
    """One row per (video, viewer) — lets us count UNIQUE viewers, not just
    raw views. `viewer_hash` is a hash of the client IP (the watch page is
    public, so there's no user id to key on)."""
    __tablename__ = "video_views"

    id = Column(UUID(as_uuid=False), primary_key=True, default=_uuid)
    video_id = Column(UUID(as_uuid=False), ForeignKey("videos.id"), nullable=False, index=True)
    viewer_hash = Column(String, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=_now)
