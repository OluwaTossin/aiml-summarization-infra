output "instance_id" { value = aws_instance.airflow.id }
output "security_group_id" { value = aws_security_group.airflow.id }
output "log_group_name" { value = aws_cloudwatch_log_group.airflow.name }
