variable "project_prefix" {
  description = "Naming prefix for all resources"
  type        = string
  default     = "aiml-summarization"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use (2 or 3 recommended)."
  type        = number
  default     = 2
}

variable "create_nat_gateway" {
  description = "Create a single NAT GW in AZ0 for private subnets egress."
  type        = bool
  default     = true
}

variable "create_vpc_endpoints" {
  description = "Create VPC endpoints for S3, ECR, SSM, CloudWatch/Logs to reduce NAT reliance."
  type        = bool
  default     = true
}

variable "allowed_admin_cidrs" {
  description = "CIDR blocks permitted to reach Airflow UI (8080). Empty = no public ingress."
  type        = list(string)
  default     = []
}

variable "iam_s3_bucket_arns" {
  description = "Optional list of S3 bucket ARNs (and /*) that EC2/SSM role may access."
  type        = list(string)
  default     = []
}

variable "use_kms" {
  description = "Create and use a KMS CMK for S3 and log groups"
  type        = bool
  default     = true
}

variable "data_bucket_name" {
  description = "Optional explicit name for data bucket"
  type        = string
  default     = ""
}

variable "log_group_names" {
  description = "CloudWatch log groups to create"
  type        = list(string)
  default     = ["/aiml/prod/app", "/aiml/prod/airflow", "/aiml/prod/infra"]
}

variable "log_retention_days" {
  description = "Retention in days for log groups"
  type        = number
  default     = 30
}

# Use these when reusing an existing VPC/subnets
variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs in the existing VPC"
  type        = list(string)
}

# ---------- CI/CD & OIDC wiring ----------
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user name (e.g., OluwaTossin)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g., AIML-SUMMARIZATION-INFRA)"
  type        = string
}

variable "github_branch" {
  description = "Branch for OIDC trust"
  type        = string
  default     = "main"
}

variable "role_name" {
  description = "Name of the GitHub OIDC role"
  type        = string
  default     = "GitHubOIDCRole"
}

variable "ecr_repo_name" {
  description = "ECR repository for Airflow image"
  type        = string
  default     = "aiml/airflow"
}

variable "ec2_instance_id" {
  description = "Airflow EC2 instance ID (target for SSM deploy)"
  type        = string
}

# ---------- Data flow parameters ----------
variable "raw_bucket" {
  description = "S3 bucket for raw inputs"
  type        = string
}

variable "processed_bucket" {
  description = "S3 bucket for summarized outputs (and preprocessed if you reuse the same bucket)"
  type        = string
}

variable "s3_input_prefix" {
  description = "Prefix for raw inputs"
  type        = string
  default     = "raw/"
}

variable "s3_output_prefix" {
  description = "Prefix for processed outputs"
  type        = string
  default     = "processed/"
}
