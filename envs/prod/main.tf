terraform {
  # backend is already defined in backend.tf
}

# Inherit default region from your AWS config (providers.tf)
# provider "aws" {} is already present at env level

############################
# Call Modules (Phase 1)
############################

module "kms" {
  source          = "../../modules/kms"
  project_prefix  = var.project_prefix
  create_data_key = var.use_kms
  alias_name      = "${var.project_prefix}-data"
}

module "s3_data" {
  source                 = "../../modules/s3"
  project_prefix         = var.project_prefix
  explicit_bucket_name   = var.data_bucket_name
  kms_key_arn            = var.use_kms ? module.kms.kms_key_arn : null
  versioning_enabled     = true
  noncurrent_expire_days = 90
}

module "logs" {
  source          = "../../modules/logs"
  project_prefix  = var.project_prefix
  log_group_names = var.log_group_names
  retention_days  = var.log_retention_days
  kms_key_arn     = var.use_kms ? module.kms.kms_key_arn : null
}


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
  source         = "../../modules/iam"
  project_prefix = var.project_prefix

  # Scope EC2/SSM role to the S3 data bucket created above,
  # while still allowing optional extra ARNs from variables.
  s3_bucket_arns = concat(
    var.iam_s3_bucket_arns,
    [
      module.s3_data.bucket_arn,
      module.s3_data.bucket_arn_with_wildcard
    ]
  )
  # NEW: pass through github repo for OIDC trust
  github_repo = var.github_repo
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

module "airflow_ec2" {
  source = "../../modules/airflow_ec2"

  project_prefix    = var.project_prefix
  vpc_id            = var.vpc_id
  private_subnet_id = var.private_subnet_ids[0]
  instance_type     = "t3.micro"

  image_uri      = "455921291596.dkr.ecr.eu-west-1.amazonaws.com/aiml-airflow-image:dev"
  log_group_name = "/aiml/prod/airflow"

  raw_bucket       = var.raw_bucket
  processed_bucket = var.processed_bucket

}
