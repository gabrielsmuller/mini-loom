# Async thumbnail pipeline: S3 upload event -> SQS -> worker Lambda.
# SQS decouples the slow thumbnail work from the upload, and gives free retries
# plus a dead-letter queue for messages that keep failing.

# Dead-letter queue: messages that fail 3 times land here instead of looping.
resource "aws_sqs_queue" "thumbnails_dlq" {
  name                      = "${var.project}-thumbnails-dlq"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "thumbnails" {
  name = "${var.project}-thumbnails"
  # Must be >= the worker's timeout so a message isn't re-delivered mid-process.
  visibility_timeout_seconds = 180

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.thumbnails_dlq.arn
    maxReceiveCount     = 3
  })
}

# Let the videos bucket send messages to the queue.
resource "aws_sqs_queue_policy" "thumbnails" {
  queue_url = aws_sqs_queue.thumbnails.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.thumbnails.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_s3_bucket.videos.arn }
      }
    }]
  })
}

# Fire an event to SQS whenever a new object lands under videos/. The prefix
# filter is important: thumbnails go under thumbnails/, so they DON'T re-trigger
# the pipeline (no infinite loop).
resource "aws_s3_bucket_notification" "videos" {
  bucket = aws_s3_bucket.videos.id

  queue {
    queue_arn     = aws_sqs_queue.thumbnails.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "videos/"
  }

  depends_on = [aws_sqs_queue_policy.thumbnails]
}
