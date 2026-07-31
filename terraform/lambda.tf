variable "image_tag" {
  description = "ECR image tag to deploy (CI/CD will use a specific tag/digest)."
  type        = string
  default     = "latest"
}

# Log group created explicitly so we can SET RETENTION. If we let Lambda create
# it implicitly, it defaults to "never expire" and logs accrue cost forever.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-api"
  retention_in_days = 30
}

# The backend, running as a container image in Lambda.
resource "aws_lambda_function" "api" {
  function_name = "${var.project}-api"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.backend.repository_url}:${var.image_tag}"

  memory_size = 512
  timeout     = 60 # room for the first request to wait out Aurora's resume + retries

  environment {
    variables = {
      # Use the RDS Data API (SQL over HTTPS) instead of a psycopg TCP socket.
      USE_DATA_API         = "true"
      AURORA_CLUSTER_ARN   = aws_rds_cluster.this.arn
      AURORA_SECRET_ARN    = aws_rds_cluster.this.master_user_secret[0].secret_arn
      AURORA_DATABASE_NAME = aws_rds_cluster.this.database_name

      VIDEO_BUCKET = aws_s3_bucket.videos.id

      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.web.id

      # Lock CORS to the live site (+ localhost for dev) instead of "*".
      CORS_ALLOW_ORIGINS = "https://${aws_cloudfront_distribution.frontend.domain_name},http://localhost:5173"
      # AWS_REGION is provided automatically by the Lambda runtime.
    }
  }

  # Ensure the log group (with retention) exists before the function.
  depends_on = [aws_cloudwatch_log_group.lambda]
}
