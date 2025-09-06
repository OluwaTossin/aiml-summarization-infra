# Compute your account id so you don't hardcode it
data "aws_caller_identity" "current" {}

module "github_oidc" {
  source = "../../modules/github_oidc"

  # Provider already exists in this account -> do not create
  create_github_oidc_provider       = false
  existing_github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  aws_region    = var.aws_region
  github_owner  = var.github_owner
  github_repo   = var.github_repo
  github_branch = var.github_branch

  role_name       = var.role_name
  ecr_repo_name   = var.ecr_repo_name
  ec2_instance_id = var.ec2_instance_id

  raw_bucket       = var.raw_bucket
  processed_bucket = var.processed_bucket
  s3_input_prefix  = var.s3_input_prefix
  s3_output_prefix = var.s3_output_prefix
}

output "github_oidc_role_arn" {
  value = module.github_oidc.role_arn
}
