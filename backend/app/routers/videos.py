"""Video endpoints: create (get upload URL), watch, list own videos."""
import hashlib
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import User, Video, VideoView
from app.schemas import VideoCreate, VideoCreateResponse, VideoOut
from app.auth import get_current_user
from app.s3 import generate_upload_post, generate_view_url, delete_object

router = APIRouter(prefix="/videos", tags=["videos"])


@router.post("", response_model=VideoCreateResponse, status_code=201)
def create_video(
    payload: VideoCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Step 1 of upload: create the DB record and hand back a pre-signed URL.
    The client then uploads the file straight to S3 using that URL.
    """
    video_id = str(uuid.uuid4())
    # Namespace the key by user and video id to avoid collisions
    s3_key = f"videos/{user.id}/{video_id}/{payload.filename}"

    video = Video(id=video_id, user_id=user.id, title=payload.title, s3_key=s3_key)
    db.add(video)
    db.commit()

    post = generate_upload_post(s3_key)
    return VideoCreateResponse(
        id=video_id,
        upload_url=post["url"],
        upload_fields=post["fields"],
        watch_url=f"/v/{video_id}",
    )


@router.get("/{video_id}/watch")
def watch_video(video_id: str, request: Request, db: Session = Depends(get_db)):
    """
    Public endpoint (no auth). Increments the raw view count, records a unique
    viewer (deduped by client-IP hash), and returns pre-signed URLs to stream
    the video and show its thumbnail.
    """
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    video.views += 1

    # Unique viewers: the page is public, so key on a hash of the client IP.
    fwd = request.headers.get("x-forwarded-for", "")
    ip = fwd.split(",")[0].strip() or (request.client.host if request.client else "unknown")
    viewer_hash = hashlib.sha256(ip.encode()).hexdigest()[:32]
    already = (
        db.query(VideoView)
        .filter(VideoView.video_id == video_id, VideoView.viewer_hash == viewer_hash)
        .first()
    )
    if not already:
        db.add(VideoView(video_id=video_id, viewer_hash=viewer_hash))
    db.commit()

    unique_viewers = db.query(VideoView).filter(VideoView.video_id == video_id).count()

    return {
        "id": video.id,
        "title": video.title,
        "views": video.views,
        "unique_viewers": unique_viewers,
        "video_url": generate_view_url(video.s3_key),
        "thumbnail_url": generate_view_url(video.thumbnail_key) if video.thumbnail_key else None,
    }


@router.get("", response_model=list[VideoOut])
def list_my_videos(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    videos = db.query(Video).filter(Video.user_id == user.id).all()
    return [
        VideoOut(
            id=v.id,
            title=v.title,
            views=v.views,
            created_at=v.created_at,
            thumbnail_url=generate_view_url(v.thumbnail_key) if v.thumbnail_key else None,
        )
        for v in videos
    ]


@router.delete("/{video_id}", status_code=204)
def delete_video(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Delete a video: removes the S3 object AND the DB row. Scoped to the owner —
    the filter on user_id means you can only delete your OWN videos (a request
    for someone else's id simply returns 404).
    """
    video = (
        db.query(Video)
        .filter(Video.id == video_id, Video.user_id == user.id)
        .first()
    )
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    # Remove the viewer rows first (they reference this video), then the file
    # and the record itself.
    db.query(VideoView).filter(VideoView.video_id == video_id).delete()
    delete_object(video.s3_key)  # remove the file from S3
    db.delete(video)             # remove the record from the database
    db.commit()
