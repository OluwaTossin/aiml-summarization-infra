locals {
  repo_map = { for r in var.repositories : r => r }
}

resource "aws_ecr_repository" "repos" {
  for_each = local.repo_map

  name                 = "${var.project_prefix}-${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # swap to KMS if you prefer CMK
  }

  tags = {
    Name        = "${var.project_prefix}-${each.value}"
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# Keep last N images (cost control + hygiene)
resource "aws_ecr_lifecycle_policy" "policy" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.retain_images} images, expire older"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.retain_images
        }
        action = { type = "expire" }
      }
    ]
  })
}
