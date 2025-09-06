output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "sg_alb_id" {
  value = aws_security_group.alb.id
}

output "sg_app_id" {
  value = aws_security_group.app.id
}

output "sg_airflow_id" {
  value = aws_security_group.airflow.id
}

output "endpoints_sg_id" {
  value = try(aws_security_group.endpoints[0].id, null)
}

output "interface_endpoint_ids" {
  value = try({ for k, ep in aws_vpc_endpoint.interfaces : k => ep.id }, {})
}

output "s3_gateway_endpoint_id" {
  value = try(aws_vpc_endpoint.s3[0].id, null)
}
