# --- OIDC provider handling ---

variable "create_github_oidc_provider" {
  description = "If true, create the IAM OIDC provider; otherwise supply existing_github_oidc_provider_arn."
  type        = bool
  default     = false
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing OIDC provider ARN (arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com). Required when create_github_oidc_provider = false."
  type        = string
  default     = ""
}

# --- Core inputs used by this module ---

variable "aws_region" {
  description = "AWS region used for ARNs and ECR scope."
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user (e.g., OluwaTossin)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g., AIML-SUMMARIZATION-INFRA)."
  type        = string
}

variable "github_branch" {
  description = "Branch to bind in OIDC trust (refs/heads/<branch>)."
  type        = string
  default     = "main"
}

variable "role_name" {
  description = "Name for the IAM role assumed by GitHub Actions via OIDC."
  type        = string
  default     = "GitHubOIDCRole"
}

variable "ecr_repo_name" {
  description = "ECR repository name that CI will push to (e.g., aiml/airflow)."
  type        = string
  default     = "aiml/airflow"
}

variable "ec2_instance_id" {
  description = "Target EC2 instance ID for SSM SendCommand during deploy."
  type        = string
}

# --- Data flow variables exported as GitHub Actions variables ---

variable "raw_bucket" {
  description = "S3 bucket for raw inputs."
  type        = string
}

variable "processed_bucket" {
  description = "S3 bucket for processed outputs."
  type        = string
}

variable "s3_input_prefix" {
  description = "S3 prefix for raw inputs."
  type        = string
  default     = "raw/"
}

variable "s3_output_prefix" {
  description = "S3 prefix for processed outputs."
  type        = string
  default     = "processed/"
}
