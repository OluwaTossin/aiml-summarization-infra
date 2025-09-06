# envs/prod/gh_oidc.tf
module "github_oidc" {
  source = "../../modules/github_oidc"

  # --- OIDC provider handling ---
  # You already have the GitHub OIDC provider in the account, so don't create a new one.
  create_github_oidc_provider       = false
  existing_github_oidc_provider_arn = "arn:aws:iam::455921291596:oidc-provider/token.actions.githubusercontent.com"

  # --- IMPORTANT: disable API creation of repo variables (avoids needing a PAT) ---
  create_actions_variables = false

  # --- Core params wired from your env variables/TFVARS ---
  aws_region = var.aws_region

  github_owner  = var.github_owner  # e.g., "OluwaTossin"
  github_repo   = var.github_repo   # e.g., "aiml-summarization-infra"
  github_branch = var.github_branch # e.g., "main"

  role_name     = var.role_name     # "GitHubOIDCRole"
  ecr_repo_name = var.ecr_repo_name # "aiml-airflow-image"

  ec2_instance_id  = var.ec2_instance_id
  raw_bucket       = var.raw_bucket
  processed_bucket = var.processed_bucket
  s3_input_prefix  = var.s3_input_prefix
  s3_output_prefix = var.s3_output_prefix
}
