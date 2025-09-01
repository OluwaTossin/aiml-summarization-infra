data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  inferred_name = lower(replace(
    "${var.project_prefix}-data-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}",
    "/[^a-z0-9-]/",
    "-"
  ))

  bucket_name = var.explicit_bucket_name != "" ? var.explicit_bucket_name : local.inferred_name
  use_kms     = var.kms_key_arn != ""
}

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
      kms_master_key_id = local.use_kms ? var.kms_key_arn : null
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

# ------- Correct, deduplicated, multi-line policy doc starts here -------
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

  # If KMS is used, require the correct KMS key
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
        values   = [var.kms_key_arn]
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
# ------- End policy doc -------

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
