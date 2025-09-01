variable "project_prefix" {
  type        = string
  description = "Prefix for naming"
}

variable "create_data_key" {
  type        = bool
  description = "Whether to create a CMK for S3/logs encryption"
  default     = true
}

variable "alias_name" {
  type        = string
  description = "KMS key alias without 'alias/' prefix"
  default     = "aiml-data"
}
