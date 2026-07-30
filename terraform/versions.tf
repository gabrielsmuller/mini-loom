# Pins the Terraform CLI and provider versions so everyone (and CI) builds the
# same infrastructure. Loose enough to get patches, strict enough to avoid
# surprise breaking changes from a new major version.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # any 5.x, but not 6.x
    }
  }
}
