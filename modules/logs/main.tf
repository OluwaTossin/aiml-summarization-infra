locals {
  use_kms = var.kms_key_arn != ""
}

resource "aws_cloudwatch_log_group" "groups" {
  for_each          = toset(var.log_group_names)
  name              = each.value
  retention_in_days = var.retention_days
  kms_key_id        = local.use_kms ? var.kms_key_arn : null

  tags = {
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
