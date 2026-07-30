"""
S3 helpers — pre-signed URLs.

Why pre-signed URLs: the browser uploads the video file DIRECTLY to S3,
never through our Lambda. This avoids Lambda's 6MB payload limit, keeps
large uploads off the API's critical path, and is exactly how real
companies handle user file uploads.

The backend only generates a short-lived, signed URL that grants permission
to PUT one specific object. It never touches the file bytes.
"""
import boto3
from botocore.config import Config

from app.config import settings

# Force Signature Version 4. SigV2 (boto3's default for the us-east-1 global
# endpoint) folds Content-Type into the signature, which breaks browser PUTs
# that send their own Content-Type header. SigV4 pre-signed URLs sign only the
# host, so the browser can send Content-Type freely.
_s3 = boto3.client(
    "s3",
    region_name=settings.aws_region,
    config=Config(signature_version="s3v4"),
)


def generate_upload_post(s3_key: str) -> dict:
    """
    Pre-signed POST for a direct-to-S3 upload with a MAX SIZE enforced by S3.

    Unlike a pre-signed PUT, a pre-signed POST carries a policy with conditions.
    The `content-length-range` condition makes S3 itself reject any upload
    larger than max_upload_bytes — real server-side enforcement, not just a UI
    check. Returns {"url": ..., "fields": {...}}; the browser sends both as a
    multipart form with the file last.
    """
    return _s3.generate_presigned_post(
        Bucket=settings.video_bucket,
        Key=s3_key,
        Conditions=[["content-length-range", 1, settings.max_upload_bytes]],
        ExpiresIn=settings.presigned_url_expire_seconds,
    )


def generate_view_url(s3_key: str) -> str:
    """Pre-signed URL the viewer uses to GET/stream the video from S3."""
    return _s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": settings.video_bucket, "Key": s3_key},
        ExpiresIn=settings.presigned_url_expire_seconds,
    )


def delete_object(s3_key: str) -> None:
    """Delete one object from the videos bucket (used when a user deletes a video)."""
    _s3.delete_object(Bucket=settings.video_bucket, Key=s3_key)
