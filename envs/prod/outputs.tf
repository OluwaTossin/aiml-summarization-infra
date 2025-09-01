output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnets" {
  value = module.network.public_subnet_ids
}

output "private_subnets" {
  value = module.network.private_subnet_ids
}

output "sg_alb_id" {
  value = module.network.sg_alb_id
}

output "sg_app_id" {
  value = module.network.sg_app_id
}

output "sg_airflow_id" {
  value = module.network.sg_airflow_id
}

output "instance_profile_name" {
  value = module.iam.instance_profile_name
}

output "ecr_repo_urls" {
  value = module.ecr.repo_urls
}
