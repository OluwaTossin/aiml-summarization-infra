terraform {
  required_providers {
    aws    = { source = "hashicorp/aws",       version = ">= 5.0" }
    github = { source = "integrations/github", version = ">= 6.0" }
    tls    = { source = "hashicorp/tls",       version = ">= 4.0" }
  }
}

locals {
  repo_full     = "${var.github_owner}/${var.github_repo}"
  branch_ref    = "refs/heads/${var.github_branch}"
  ecr_repo_name = var.ecr_repo_name
}

data "aws_caller_identity" "this" {}

# Thumbprint only needed when we create the provider
data "tls_certificate" "gh_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

# Create provider only if requested (default false to avoid 409 when it already exists)
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.gh_oidc.certificates[0].sha1_fingerprint]
}

# ----- OIDC ARN selection (robust to count = 0) -----
locals {
  gh_oidc_created_arn    = try(aws_iam_openid_connect_provider.github[0].arn, "")
  gh_oidc_arn            = var.create_github_oidc_provider ? local.gh_oidc_created_arn : var.existing_github_oidc_provider_arn
  validate_existing_oidc = var.create_github_oidc_provider || length(trimspace(local.gh_oidc_arn)) > 0
}

# Fail-fast with a readable error if misconfigured
resource "null_resource" "validate_oidc" {
  triggers = {
    ok = tostring(local.validate_existing_oidc)
  }
  provisioner "local-exec" {
    when        = create
    command     = "test ${local.validate_existing_oidc} = true || (echo 'ERROR: existing_github_oidc_provider_arn must be set when create_github_oidc_provider = false' && exit 1)"
    interpreter = ["/bin/sh", "-c"]
  }
  lifecycle {
    ignore_changes = [triggers]
  }
}

# -------- Assume role policy bound to the OIDC provider + your repo/branch --------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.gh_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo_full}:ref:${local.branch_ref}"]
    }
  }
}

resource "aws_iam_role" "github_oidc_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  description        = "GitHub Actions OIDC role for ${local.repo_full}"
}

# -------- Least-privilege policy: ECR push for a specific repo + SSM SendCommand to a specific instance --------
data "aws_iam_policy_document" "inline" {
  statement {
    sid      = "EcrAuthGlobal"
    actions  = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrMutateSpecificRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:ListImages",
      "ecr:DescribeRepositories"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.this.account_id}:repository/${local.ecr_repo_name}"
    ]
  }

  statement {
    sid = "SsmSendCommandToAirflowInstance"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations"
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.this.account_id}:instance/${var.ec2_instance_id}",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.this.account_id}:document/AWS-RunShellScript"
    ]
  }
}

resource "aws_iam_role_policy" "inline" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.github_oidc_role.id
  policy = data.aws_iam_policy_document.inline.json
}

# -------- GitHub Actions repo variables (read by your workflow via vars.*) --------
resource "github_actions_variable" "aws_region" {
  repository    = var.github_repo
  variable_name = "AWS_REGION"
  value         = var.aws_region
}

resource "github_actions_variable" "aws_account_id" {
  repository    = var.github_repo
  variable_name = "AWS_ACCOUNT_ID"
  value         = data.aws_caller_identity.this.account_id
}

resource "github_actions_variable" "ec2_instance_id" {
  repository    = var.github_repo
  variable_name = "EC2_INSTANCE_ID"
  value         = var.ec2_instance_id
}

resource "github_actions_variable" "raw_bucket" {
  repository    = var.github_repo
  variable_name = "RAW_BUCKET"
  value         = var.raw_bucket
}

resource "github_actions_variable" "processed_bucket" {
  repository    = var.github_repo
  variable_name = "PROCESSED_BUCKET"
  value         = var.processed_bucket
}

resource "github_actions_variable" "s3_input_prefix" {
  repository    = var.github_repo
  variable_name = "S3_INPUT_PREFIX"
  value         = var.s3_input_prefix
}

resource "github_actions_variable" "s3_output_prefix" {
  repository    = var.github_repo
  variable_name = "S3_OUTPUT_PREFIX"
  value         = var.s3_output_prefix
}
