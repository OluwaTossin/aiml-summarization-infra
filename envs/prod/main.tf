terraform {
  # backend is already defined in backend.tf
}

# Inherit default region from your AWS config (providers.tf)
# provider "aws" {} is already present at env level

############################
# Call Modules (Phase 1)
############################

module "network" {
  source = "../../modules/network"

  project_prefix = var.project_prefix
  vpc_cidr       = var.vpc_cidr
  az_count       = var.az_count

  # Cost & privacy controls
  create_nat_gateway   = var.create_nat_gateway   # true = single NAT GW in AZ0
  create_vpc_endpoints = var.create_vpc_endpoints # strongly recommended

  # Admin ingress for Airflow (optional; default empty = no public ingress)
  allowed_admin_cidrs = var.allowed_admin_cidrs
}

module "iam" {
  source = "../../modules/iam"

  project_prefix = var.project_prefix

  # Optional: Limit S3 rights for EC2/SSM role (app/airflow) to specific buckets
  # Provide ARNs like "arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"
  s3_bucket_arns = var.iam_s3_bucket_arns
}

module "ecr" {
  source = "../../modules/ecr"

  project_prefix = var.project_prefix

  # Repositories you want pre-created
  repositories = [
    "summarizer-app", # Streamlit/FastAPI + HF model
    "airflow-image"   # optional image for Airflow workers if you containerize
  ]

  # Keep last N images to control storage/cost
  retain_images = 10
}
