output "repo_urls" {
  description = "Map of short repo name to repository URI"
  value       = { for k, r in aws_ecr_repository.repos : k => r.repository_url }
}
