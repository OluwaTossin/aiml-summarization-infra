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
  description = "List of CIDR blocks permitted to reach Airflow UI (8080). Empty = no public ingress."
  type        = list(string)
  default     = []
}

variable "iam_s3_bucket_arns" {
  description = "Optional list of S3 bucket ARNs (and /*) that EC2/SSM role may access."
  type        = list(string)
  default     = []
}
