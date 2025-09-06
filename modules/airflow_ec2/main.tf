terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

# Latest Amazon Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# CloudWatch log group for container stdout/stderr
resource "aws_cloudwatch_log_group" "airflow" {
  name              = var.log_group_name
  retention_in_days = 14
}

# Minimal security group: no ingress needed (SSM uses outbound only)
resource "aws_security_group" "airflow" {
  # Use name_prefix so TF can create a new SG before deleting the old one
  name_prefix = "${var.project_prefix}-airflow-sg-"
  description = "Airflow host (private); no ingress. Egress only."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "${var.project_prefix}-airflow-sg"
    Project   = var.project_prefix
    ManagedBy = "Terraform"
  }
}

# IAM role + instance profile (SSM, ECR, logs, S3, optional Lambda invoke)
resource "aws_iam_role" "ec2" {
  name               = "${var.project_prefix}-airflow-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Minimal CW logs permissions (avoid full admin)
data "aws_iam_policy_document" "logs" {
  statement {
    actions = [
      "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}
resource "aws_iam_policy" "logs" {
  name   = "${var.project_prefix}-airflow-logs"
  policy = data.aws_iam_policy_document.logs.json
}
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.logs.arn
}

# S3 access to raw and processed prefixes
data "aws_iam_policy_document" "s3_data" {
  statement {
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.raw_bucket}",
      "arn:aws:s3:::${var.processed_bucket}"
    ]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.raw_bucket}/raw/*"]
  }
  statement {
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "arn:aws:s3:::${var.processed_bucket}/cleaned/*",
      "arn:aws:s3:::${var.processed_bucket}/summaries/*"
    ]
  }
}
resource "aws_iam_policy" "s3_data" {
  name   = "${var.project_prefix}-airflow-s3"
  policy = data.aws_iam_policy_document.s3_data.json
}
resource "aws_iam_role_policy_attachment" "s3_data" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3_data.arn
}

# Optional Lambda invoke (Phase 3)
data "aws_iam_policy_document" "lambda_invoke" {
  count = var.summarizer_lambda_arn == "" ? 0 : 1
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [var.summarizer_lambda_arn]
  }
}
resource "aws_iam_policy" "lambda_invoke" {
  count  = var.summarizer_lambda_arn == "" ? 0 : 1
  name   = "${var.project_prefix}-airflow-lambda-invoke"
  policy = data.aws_iam_policy_document.lambda_invoke[0].json
}
resource "aws_iam_role_policy_attachment" "lambda_invoke" {
  count      = var.summarizer_lambda_arn == "" ? 0 : 1
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.lambda_invoke[0].arn
}

# SSM Parameter read for admin creds
data "aws_iam_policy_document" "ssm_params" {
  statement {
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${data.aws_region.this.id}:${data.aws_caller_identity.this.account_id}:parameter${var.ssm_param_admin_user}",
      "arn:aws:ssm:${data.aws_region.this.id}:${data.aws_caller_identity.this.account_id}:parameter${var.ssm_param_admin_pwd}",
      "arn:aws:ssm:${data.aws_region.this.id}:${data.aws_caller_identity.this.account_id}:parameter${var.ssm_param_admin_email}"
    ]
  }
}
resource "aws_iam_policy" "ssm_params" {
  name   = "${var.project_prefix}-airflow-ssm"
  policy = data.aws_iam_policy_document.ssm_params.json
}
resource "aws_iam_role_policy_attachment" "ssm_params" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ssm_params.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_prefix}-airflow-ec2-profile"
  role = aws_iam_role.ec2.name
}

# Private EC2 host
resource "aws_instance" "airflow" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.airflow.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false

  # >>> Instance memory <<<
  root_block_device {
    volume_size           = 30 # 30 GiB is a sensible minimum for Docker + Airflow
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }


  user_data = <<-EOF
    #!/usr/bin/env bash
    set -eux

    # ---------- SSM Agent (ensure installed and running) ----------
    dnf update -y
    dnf install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
    systemctl status amazon-ssm-agent --no-pager || true

    # ---------- Docker ----------
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user || true

    REGION=${data.aws_region.this.id}
    ACCOUNT=${data.aws_caller_identity.this.account_id}
    ECR_REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

    # ECR auth
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

    # Read admin creds from SSM (pwd may be SecureString; SSM handles decrypt server-side)
    ADMIN_USER=$(aws ssm get-parameter --name "${var.ssm_param_admin_user}" --query Parameter.Value --output text)
    ADMIN_PWD=$(aws ssm get-parameter --with-decryption --name "${var.ssm_param_admin_pwd}"  --query Parameter.Value --output text)
    ADMIN_EMAIL=$(aws ssm get-parameter --name "${var.ssm_param_admin_email}" --query Parameter.Value --output text)

    # Airflow runtime volume
    docker volume create airflow_home || true

    # Pull + run Airflow
    docker pull ${var.image_uri}
    docker rm -f airflow 2>/dev/null || true

    docker run -d --name airflow \
      -p 8080:8080 \
      --restart unless-stopped \
      --log-driver awslogs \
      --log-opt awslogs-region=$REGION \
      --log-opt awslogs-group=${var.log_group_name} \
      --log-opt awslogs-stream=${var.project_prefix}-airflow-web \
      -e AIRFLOW_ADMIN_USER="$ADMIN_USER" \
      -e AIRFLOW_ADMIN_PWD="$ADMIN_PWD" \
      -e AIRFLOW_ADMIN_EMAIL="$ADMIN_EMAIL" \
      -e AWS_DEFAULT_REGION="$REGION" \
      -v airflow_home:/opt/airflow \
      ${var.image_uri}
  EOF

  tags = {
    Name        = "${var.project_prefix}-airflow-ec2"
    Project     = var.project_prefix
    ManagedBy   = "Terraform"
    Environment = "prod"
  }
}
