"""
SQS-triggered thumbnail worker.

Flow: S3 emits an ObjectCreated event when a video finishes uploading -> SQS ->
this Lambda. It downloads the video, grabs a frame, writes a JPEG thumbnail
back to S3, and records the thumbnail's key on the video row.

Runs from the SAME container image as the API, just with a different handler
(app.worker.handler), set via the Lambda's image_config in Terraform.
"""
import json
import os
import tempfile
import urllib.parse

import boto3
import imageio.v2 as imageio
from PIL import Image

from app.config import settings
from app.database import SessionLocal, init_db
from app.models import Video

_s3 = boto3.client("s3", region_name=settings.aws_region)


def _thumbnail_key(video_key: str) -> str:
    """videos/<user>/<id>/file.mp4  ->  thumbnails/<user>/<id>/thumb.jpg"""
    parts = video_key.split("/")
    return "/".join(["thumbnails"] + parts[1:-1] + ["thumb.jpg"])


def _process(bucket: str, key: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        video_path = os.path.join(tmp, "input")
        thumb_path = os.path.join(tmp, "thumb.jpg")

        _s3.download_file(bucket, key, video_path)

        # Grab the first frame (force the ffmpeg plugin since the temp file has
        # no extension for imageio to sniff).
        reader = imageio.get_reader(video_path, format="FFMPEG")
        frame = reader.get_data(0)
        reader.close()

        img = Image.fromarray(frame).convert("RGB")
        img.thumbnail((480, 480))  # keeps aspect ratio
        img.save(thumb_path, "JPEG", quality=80)

        thumb_key = _thumbnail_key(key)
        _s3.upload_file(
            thumb_path, bucket, thumb_key,
            ExtraArgs={"ContentType": "image/jpeg"},
        )

        # Record the thumbnail key on the video row. The video id is the 3rd
        # path segment: videos/<user>/<video_id>/<file>.
        video_id = key.split("/")[2]
        init_db()
        db = SessionLocal()
        try:
            video = db.query(Video).filter(Video.id == video_id).first()
            if video:
                video.thumbnail_key = thumb_key
                db.commit()
        finally:
            db.close()


def handler(event, context):
    """SQS batch handler. Each SQS message body is an S3 event notification."""
    for record in event.get("Records", []):
        body = json.loads(record["body"])
        # S3 sends a one-off "s3:TestEvent" with no Records — skip those.
        for s3_record in body.get("Records", []):
            bucket = s3_record["s3"]["bucket"]["name"]
            key = urllib.parse.unquote_plus(s3_record["s3"]["object"]["key"])
            _process(bucket, key)
