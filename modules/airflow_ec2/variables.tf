variable "project_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "image_uri" {
  type = string # ECR image URI with tag, e.g. 4559.../aiml-summarization-airflow-image:dev
}

variable "log_group_name" {
  type    = string
  default = "/aiml/prod/airflow"
}

# S3 buckets
variable "raw_bucket" {
  type = string # e.g., aiml-raw-4559...-eu-west-1
}

variable "processed_bucket" {
  type = string # e.g., aiml-processed-4559...-eu-west-1
}

# (Optional) Lambda invoke for Phase 3; leave empty for now
variable "summarizer_lambda_arn" {
  type    = string
  default = ""
}

# Admin creds source: recommend SSM Parameter Store names (SecureString)
variable "ssm_param_admin_user" {
  type    = string
  default = "/aiml/prod/airflow/admin_user"
}

variable "ssm_param_admin_pwd" {
  type    = string
  default = "/aiml/prod/airflow/admin_pwd"
}

variable "ssm_param_admin_email" {
  type    = string
  default = "/aiml/prod/airflow/admin_email"
}
