output "kms_key_arn" {
  value       = try(aws_kms_key.data[0].arn, null)
  description = "ARN of the KMS CMK (if created)"
}

output "kms_alias" {
  value       = try(aws_kms_alias.data[0].name, null)
  description = "KMS alias (if created)"
}
