output "state_bucket" {
  description = "Name of the S3 bucket for Terraform state."
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table" {
  description = "Name of the DynamoDB table for state locks."
  value       = aws_dynamodb_table.locks.name
}

output "region" {
  description = "AWS region resolved by the provider."
  value       = data.aws_region.current.id
}

