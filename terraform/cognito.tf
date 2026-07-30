# Cognito: managed authentication with Google sign-in.
#
# Four pieces:
#   1. user_pool          — the directory of users + the token issuer
#   2. domain             — the hosted login page ("Sign in with Google" screen)
#   3. identity_provider  — tells Cognito how to federate to Google
#   4. user_pool_client   — your app's registration (which flows/URLs allowed)

# 1) The user pool: stores users and issues the JWTs your API will trust.
resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-users"

  # Users are identified by email (pulled from their Google account).
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
}

# 2) Hosted UI domain: the AWS-provided login page. The prefix must be globally
#    unique, so we suffix it with the account id.
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# 3) Google as an identity provider. The client id/secret come from a Google
#    Cloud OAuth client (you create that; values go in terraform.tfvars).
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }

  # Map Google's fields onto Cognito user attributes.
  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

# 4) The app client: registers your frontend and defines the allowed OAuth flow.
resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  # Public client (a browser SPA can't keep a secret), so no client secret.
  generate_secret = false

  # Authorization Code flow — the secure, standard flow for web apps.
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  supported_identity_providers = ["Google"]

  # Allow both local dev (from the vars) AND the deployed CloudFront URL, so the
  # same pool works for `npm run dev` and the live site.
  callback_urls = concat(var.cognito_callback_urls, ["https://${aws_cloudfront_distribution.frontend.domain_name}"])
  logout_urls   = concat(var.cognito_logout_urls, ["https://${aws_cloudfront_distribution.frontend.domain_name}"])

  # Make sure the Google provider exists before the client references it.
  depends_on = [aws_cognito_identity_provider.google]
}

# ---- Outputs the backend and frontend need ----
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_domain" {
  description = "Hosted UI base URL for the login page."
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_issuer" {
  description = "Token issuer URL; the backend/API Gateway verify JWTs against its JWKS."
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}
