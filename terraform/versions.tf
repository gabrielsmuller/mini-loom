# Pins the Terraform CLI and provider versions so everyone (and CI) builds the
# same infrastructure. Loose enough to get patches, strict enough to avoid
# surprise breaking changes from a new major version.
terraform {
  required_version = ">= 1.10" # use_lockfile (S3-native state locking) needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # any 5.x, but not 6.x
    }
  }

  # Remote state in S3 so both your laptop and GitHub Actions share one state.
  # use_lockfile = S3-native locking (no DynamoDB table needed).
  backend "s3" {
    bucket       = "mini-loom-tfstate-958620575923"
    key          = "mini-loom/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
