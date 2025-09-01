variable "project_prefix" {
  type        = string
  description = "Prefix for naming"
}

variable "explicit_bucket_name" {
  type        = string
  description = "Optional explicit S3 bucket name. Leave blank to auto-generate."
  default     = ""
}

variable "kms_key_arn" {
  type        = string
  description = "Optional KMS CMK ARN to use for SSE-KMS"
  default     = ""
}

variable "versioning_enabled" {
  type    = bool
  default = true
}

variable "noncurrent_expire_days" {
  type    = number
  default = 90
}
