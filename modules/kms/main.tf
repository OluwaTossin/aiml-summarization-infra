data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Minimal, CWL-friendly key policy:
# - Root admin full control
# - CloudWatch Logs service (regional) can use the key and create grants,
#   scoped by EncryptionContext to your account's Logs ARNs, and restricted to AWS-managed grants.
data "aws_iam_policy_document" "kms" {
  # 1) Root admin
  statement {
    sid = "AllowRootAccountAdmin"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # 2) CloudWatch Logs may use the key for encrypted log groups
  statement {
    sid = "AllowCloudWatchLogsUseOfTheKey"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.id}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]

    # Grant is for an AWS-managed resource (required for CWL)
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

    # Bind usage to this account's CWL resources via encryption context
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "data" {
  count                   = var.create_data_key ? 1 : 0
  description             = "${var.project_prefix} data key"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  multi_region            = false
  policy                  = data.aws_iam_policy_document.kms.json

  tags = {
    Name        = "${var.project_prefix}-data-kms"
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "data" {
  count         = var.create_data_key ? 1 : 0
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.data[0].key_id
}
