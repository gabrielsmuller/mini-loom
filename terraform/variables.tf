# Input variables — the knobs for this stack. Values with a default are
# optional; `alert_email` has no default, so Terraform will refuse to run
# until you provide it (see terraform.tfvars.example). That's deliberate: a
# budget alarm with nobody to email is useless.

variable "project" {
  description = "Name prefix applied to resources and tags."
  type        = string
  default     = "mini-loom"
}

variable "aws_region" {
  description = "AWS region to deploy into. Kept as us-east-1 because CloudFront/ACM certs must live there."
  type        = string
  default     = "us-east-1"
}

variable "budget_limit_usd" {
  description = "Monthly spend limit that triggers alerts. The AWS provider expects this as a string."
  type        = string
  default     = "5"
}

variable "alert_email" {
  description = "Email address that receives budget alerts. Required."
  type        = string
}

variable "video_cors_origins" {
  description = "Origins allowed to upload/stream directly to the videos bucket. Starts permissive for local dev; tighten to the CloudFront domain once it exists."
  type        = list(string)
  default     = ["*"]
}

variable "budget_action_target_user" {
  description = "IAM user the budget brake restricts if spend hits 100% of the budget. This is the deploy user."
  type        = string
  default     = "terraform-user"
}

# ---- Cognito / Google login ----
variable "google_client_id" {
  description = "OAuth client ID from Google Cloud (for Cognito's Google identity provider)."
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "OAuth client secret from Google Cloud. Sensitive; set in terraform.tfvars (gitignored)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cognito_callback_urls" {
  description = "URLs Cognito may redirect back to after login. The OIDC library returns to the app root."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "cognito_logout_urls" {
  description = "URLs Cognito may redirect to after logout."
  type        = list(string)
  default     = ["http://localhost:5173"]
}
