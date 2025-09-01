output "bucket_name" {
  value = aws_s3_bucket.data.bucket
}
output "bucket_arn" {
  value = aws_s3_bucket.data.arn
}
output "bucket_arn_with_wildcard" {
  value = "${aws_s3_bucket.data.arn}/*"
}
