data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------
# Normalization & derivations
# ---------------------------
locals {
  # Clean up optional inputs that may be null or empty strings
  explicit_bucket_name_clean = (
    var.explicit_bucket_name != null && var.explicit_bucket_name != "" ? var.explicit_bucket_name : null
  )

  kms_key_arn_clean = (
    var.kms_key_arn != null && var.kms_key_arn != "" ? var.kms_key_arn : null
  )

  # Projected names
  inferred_name = lower(replace(
    "${var.project_prefix}-data-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}",
    "/[^a-z0-9-]/",
    "-"
  ))

  bucket_name = coalesce(local.explicit_bucket_name_clean, local.inferred_name)

  # True only when we actually have a valid KMS key ARN
  use_kms = local.kms_key_arn_clean != null
}

# -------------
# S3 primitives
# -------------
resource "aws_s3_bucket" "data" {
  bucket        = local.bucket_name
  force_destroy = false

  tags = {
    Name        = local.bucket_name
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
    Purpose     = "AppData"
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? local.kms_key_arn_clean : null
    }
    bucket_key_enabled = local.use_kms
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expire_days
    }
  }
}

# ----------------------------------------
# Policy: TLS required; SSE rules enforced
# ----------------------------------------
data "aws_iam_policy_document" "bucket_policy" {
  # Deny any non-TLS access
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.data.arn,
      "${aws_s3_bucket.data.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # If KMS is used, require aws:kms on PutObject
  dynamic "statement" {
    for_each = local.use_kms ? [1] : []
    content {
      sid     = "DenyPutWithoutKms"
      effect  = "Deny"
      actions = ["s3:PutObject"]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      resources = ["${aws_s3_bucket.data.arn}/*"]

      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms"]
      }
    }
  }

  # If KMS is used, require the correct KMS key (only when a real ARN exists)
  dynamic "statement" {
    for_each = local.use_kms ? [1] : []
    content {
      sid     = "DenyPutWithWrongKmsKey"
      effect  = "Deny"
      actions = ["s3:PutObject"]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      resources = ["${aws_s3_bucket.data.arn}/*"]

      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [local.kms_key_arn_clean] # <-- guaranteed non-null here
      }
    }
  }

  # If not using KMS, require AES256 on PutObject
  dynamic "statement" {
    for_each = local.use_kms ? [] : [1]
    content {
      sid     = "DenyPutWithoutSSE"
      effect  = "Deny"
      actions = ["s3:PutObject"]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      resources = ["${aws_s3_bucket.data.arn}/*"]

      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["AES256"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
