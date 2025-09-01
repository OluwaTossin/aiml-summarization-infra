data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # Use the region data source id (e.g., "eu-west-1") — name is deprecated.
  inferred_bucket_name = lower(
    replace(
      "${var.project_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}",
      "/[^a-z0-9-]/",
      "-"
    )
  )
  bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : local.inferred_bucket_name
}

resource "aws_s3_bucket" "tf_state" {
  bucket = local.bucket_name

  # Prevent accidental deletion in prod; flip to false only when intentionally destroying.
  force_destroy = false

  tags = {
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
    Purpose     = "TerraformState"
  }
}

# Ownership & ACL best practice: disable ACLs and enforce bucket-owner ownership
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block all public access (belt & suspenders)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption (SSE-S3) for simplicity; can swap to SSE-KMS later
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning is critical for state recovery
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Optional: lifecycle to expire noncurrent versions after 90 days (tunable)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    # Apply to all objects by providing an empty filter block.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
    Purpose     = "TerraformStateLock"
  }
}
