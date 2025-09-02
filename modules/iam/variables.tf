variable "project_prefix" {
  type        = string
  description = "Prefix for IAM naming"
}

variable "s3_bucket_arns" {
  type        = list(string)
  description = "Optional S3 bucket ARNs this role may access (add both bucket and bucket/*)"
  default     = []
}

variable "github_repo" {
  type        = string
  description = "GitHub org/repo for OIDC trust (e.g., user/repo)"
}
