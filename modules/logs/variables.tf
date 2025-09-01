variable "project_prefix" {
  type = string
}

variable "log_group_names" {
  type        = list(string)
  description = "List of log group names to create"
  default     = [
    "/aiml/prod/app",
    "/aiml/prod/airflow",
    "/aiml/prod/infra"
  ]
}

variable "retention_days" {
  type    = number
  default = 30
}

variable "kms_key_arn" {
  type        = string
  description = "Optional KMS key for encrypting log groups"
  default     = ""
}
