# Configures the AWS provider: which region to build in, and a set of tags
# automatically applied to EVERY resource. Those default_tags are how you make
# a project's costs easy to find later in the AWS billing console.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
