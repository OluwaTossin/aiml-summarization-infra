variable "project_prefix" {
  description = "Prefix for naming backend resources."
  type        = string
  default     = "aiml-summarization"
}

variable "s3_bucket_name" {
  description = "Explicit S3 bucket name for TF state (leave blank to auto-generate)."
  type        = string
  default     = ""
}

variable "dynamodb_table_name" {
  description = "DynamoDB table for state locking."
  type        = string
  default     = "tf-state-locks"
}

variable "s3_acl" {
  description = "Bucket ownership mode; ACLs disabled with BucketOwnerEnforced."
  type        = string
  default     = "private"
}
