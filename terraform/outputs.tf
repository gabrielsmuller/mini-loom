# Values other steps (and you) need. After `apply`, see them with
# `terraform output`. The Lambda step will feed the first three into the
# backend so it can talk to Aurora over the Data API.

output "aurora_cluster_arn" {
  description = "Cluster ARN — the Data API addresses the DB by ARN, not host/port."
  value       = aws_rds_cluster.this.arn
}

output "aurora_secret_arn" {
  description = "Secrets Manager ARN holding the DB credentials (RDS-managed)."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "aurora_database_name" {
  description = "Default database name inside the cluster."
  value       = aws_rds_cluster.this.database_name
}

output "frontend_bucket" {
  description = "Name of the S3 bucket that will hold the built React app."
  value       = aws_s3_bucket.frontend.id
}

output "videos_bucket" {
  description = "Name of the S3 bucket that holds uploaded videos."
  value       = aws_s3_bucket.videos.id
}
