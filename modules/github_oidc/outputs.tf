# Robust: works whether we created the provider (count=1) or reused an existing one (count=0)
output "oidc_provider_arn" {
  value       = local.gh_oidc_arn
  description = "ARN of the GitHub OIDC provider used by this module."
}

output "role_arn" {
  value       = aws_iam_role.github_oidc_role.arn
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC."
}
