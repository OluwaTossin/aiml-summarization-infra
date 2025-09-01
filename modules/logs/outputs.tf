output "log_group_names" {
  value = [for _, g in aws_cloudwatch_log_group.groups : g.name]
}
