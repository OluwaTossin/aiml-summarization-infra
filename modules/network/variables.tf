variable "project_prefix" {
  type        = string
  description = "Prefix tag/name"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "az_count" {
  type        = number
  description = "Number of AZs"
}

variable "create_nat_gateway" {
  type        = bool
  description = "Whether to create a single NAT GW in the first public subnet"
}

variable "create_vpc_endpoints" {
  type        = bool
  description = "Create S3 gateway and core interface endpoints for private egress"
}

variable "allowed_admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach Airflow UI (8080). Empty -> no public ingress rule"
  default     = []
}
