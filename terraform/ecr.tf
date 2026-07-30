# A private container registry for the backend image. Terraform creates the
# empty repo; you (and later CI/CD) build the image and push it here. The
# Lambda in the next step pulls from this repo.
resource "aws_ecr_repository" "backend" {
  name = "${var.project}-backend"

  # Scan images for known vulnerabilities on every push (free, good hygiene).
  image_scanning_configuration {
    scan_on_push = true
  }

  # Let `terraform destroy` remove the repo even if it still holds images.
  # Convenient for a portfolio project you'll tear down and rebuild.
  force_delete = true
}

output "ecr_repository_url" {
  description = "Push the backend image here (docker tag/push target)."
  value       = aws_ecr_repository.backend.repository_url
}
