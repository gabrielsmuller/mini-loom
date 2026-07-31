# The thumbnail worker Lambda. Same container image as the API, but overrides
# the handler to app.worker.handler and is triggered by the SQS queue.

# --- IAM role (least privilege for the worker's job) ---
resource "aws_iam_role" "worker" {
  name = "${var.project}-worker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_logs" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "worker_app" {
  name = "${var.project}-worker-app"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AuroraDataApi"
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction",
        ]
        Resource = aws_rds_cluster.this.arn
      },
      {
        Sid      = "ReadDbSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_rds_cluster.this.master_user_secret[0].secret_arn
      },
      {
        Sid      = "VideoObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"] # read video, write thumbnail
        Resource = "${aws_s3_bucket.videos.arn}/*"
      },
      {
        Sid      = "ConsumeQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.thumbnails.arn
      },
    ]
  })
}

# --- Log group with retention (same guardrail as the API) ---
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${var.project}-worker"
  retention_in_days = 30
}

# --- The function ---
resource "aws_lambda_function" "worker" {
  function_name = "${var.project}-worker"
  role          = aws_iam_role.worker.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.backend.repository_url}:${var.image_tag}"

  # Override the image's default handler to run the worker instead of the API.
  image_config {
    command = ["app.worker.handler"]
  }

  memory_size = 1024 # frame decoding + Pillow want some headroom
  timeout     = 120  # < the queue's 180s visibility timeout

  ephemeral_storage {
    size = 1024 # /tmp space to download the video (up to the 200MB cap)
  }

  environment {
    variables = {
      USE_DATA_API         = "true"
      AURORA_CLUSTER_ARN   = aws_rds_cluster.this.arn
      AURORA_SECRET_ARN    = aws_rds_cluster.this.master_user_secret[0].secret_arn
      AURORA_DATABASE_NAME = aws_rds_cluster.this.database_name
      VIDEO_BUCKET         = aws_s3_bucket.videos.id
    }
  }

  depends_on = [aws_cloudwatch_log_group.worker]
}

# --- Wire the queue to the worker ---
resource "aws_lambda_event_source_mapping" "worker_sqs" {
  event_source_arn = aws_sqs_queue.thumbnails.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
}
