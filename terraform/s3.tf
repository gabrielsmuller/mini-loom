# Two buckets, two jobs:
#   - frontend: holds the built React app (index.html, JS, CSS). Served ONLY
#     through CloudFront (we wire that up in a later step), never public.
#   - videos:   holds uploaded video files. Reached ONLY via pre-signed URLs,
#     never public.
# Both are private. S3 bucket names are GLOBALLY unique across all of AWS, so
# we suffix them with the account id to avoid collisions.

data "aws_caller_identity" "current" {}

locals {
  frontend_bucket_name = "${var.project}-frontend-${data.aws_caller_identity.current.account_id}"
  videos_bucket_name   = "${var.project}-videos-${data.aws_caller_identity.current.account_id}"
}

# ---------- Frontend bucket ----------
resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name
}

# Block every form of public access. The app is reached through CloudFront,
# not by hitting the bucket URL directly.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- Videos bucket ----------
resource "aws_s3_bucket" "videos" {
  bucket = local.videos_bucket_name
}

resource "aws_s3_bucket_public_access_block" "videos" {
  bucket                  = aws_s3_bucket.videos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The browser uploads (PUT) and streams (GET) directly to this bucket from a
# different origin (the CloudFront/localhost site), so S3 must allow those
# cross-origin requests. This is the same CORS idea from the backend, but
# enforced by S3 for the direct-to-S3 transfer.
resource "aws_s3_bucket_cors_configuration" "videos" {
  bucket = aws_s3_bucket.videos.id

  cors_rule {
    allowed_methods = ["POST", "PUT", "GET", "HEAD"]
    # Only the live site (+ localhost for dev) may upload/stream directly.
    allowed_origins = [
      "https://${aws_cloudfront_distribution.frontend.domain_name}",
      "http://localhost:5173",
    ]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Auto-delete uploaded videos 7 days after upload. Bounds storage cost as a
# safety net. NOTE: this deletes the S3 OBJECT only; the matching database row
# is not touched, so an expired video would 404 on watch. A scheduled cleanup
# of expired rows (EventBridge + Lambda) is the Phase 3 way to keep them in sync.
resource "aws_s3_bucket_lifecycle_configuration" "videos" {
  bucket = aws_s3_bucket.videos.id

  rule {
    id     = "expire-videos-after-7-days"
    status = "Enabled"

    filter {} # apply to all objects in the bucket

    expiration {
      days = 7
    }
  }
}
