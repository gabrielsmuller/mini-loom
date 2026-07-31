# GitHub Actions → AWS via OIDC (no stored access keys).
#
# GitHub presents a short-lived OIDC token; AWS trusts it only when it comes
# from THIS repo's main branch, and lets the workflow assume a role.

# The OIDC identity provider for GitHub Actions (one per AWS account).
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# The role the workflow assumes. The trust policy is scoped to your repo's
# main branch — no other repo (or branch) can assume it.
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Any ref/event in this repo. Scoped to the repo, which is the
          # security boundary; the exact-branch match is fussy across event types.
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

# The pipeline runs terraform apply + pushes images + syncs S3 + invalidates
# CloudFront, so it needs broad access. AdministratorAccess is pragmatic for a
# solo portfolio; a production setup would scope this down.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  description = "Set this as the role-to-assume in the GitHub Actions workflow."
  value       = aws_iam_role.github_actions.arn
}
