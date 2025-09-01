variable "project_prefix" {
  type = string
}

variable "repositories" {
  type        = list(string)
  description = "List of ECR repository names to create"
}

variable "retain_images" {
  type        = number
  description = "How many images to retain via lifecycle policy"
  default     = 10
}
