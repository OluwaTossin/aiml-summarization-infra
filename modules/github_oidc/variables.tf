# --- OIDC provider controls ---
variable "create_github_oidc_provider" {
  description = "Create the IAM OIDC provider for GitHub. If false, you must supply existing_github_oidc_provider_arn."
  type        = bool
  default     = false
}

variable "existing_github_oidc_provider_arn" {
  description = "Pre-existing OIDC provider ARN (arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com) when not creating."
  type        = string
  default     = ""
}

# Optional: allow this module to create GitHub Actions repo variables via API.
# Leave false if you don't want/need this or don't have a PAT with Actions write.
variable "create_actions_variables" {
  description = "If true, create GitHub Actions repository variables (requires PAT with Actions: Read/Write)."
  type        = bool
  default     = false
}

# --- Core parameters used by the module ---
variable "aws_region" { type = string }

variable "github_owner" {
  description = "GitHub org/user (e.g., OluwaTossin)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g., aiml-summarization-infra)"
  type        = string
}

variable "github_branch" {
  description = "Branch protected for OIDC (e.g., main)"
  type        = string
  default     = "main"
}

variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions"
  type        = string
  default     = "GitHubOIDCRole"
}

variable "ecr_repo_name" {
  description = "Target ECR repository name for pushes"
  type        = string
  default     = "aiml-airflow-image"
}

variable "ec2_instance_id" {
  description = "EC2 instance ID that SSM will target for deploy"
  type        = string
}

variable "raw_bucket" {
  description = "S3 bucket for raw inputs"
  type        = string
}

variable "processed_bucket" {
  description = "S3 bucket for processed/summarized outputs"
  type        = string
}

variable "s3_input_prefix" {
  description = "S3 prefix for raw inputs"
  type        = string
  default     = "raw/"
}

variable "s3_output_prefix" {
  description = "S3 prefix for processed outputs"
  type        = string
  default     = "processed/"
}
