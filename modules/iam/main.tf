#############################
# EC2 Instance Role for Airflow/App nodes (SSM-first)
#############################

resource "aws_iam_role" "ec2_ssm_role" {
  name               = "${var.project_prefix}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags = {
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
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

# Attach AWS managed policies for SSM and CloudWatch agent
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Minimal ECR pull permissions (auth + pull) and basic Logs
data "aws_iam_policy_document" "inline" {
  statement {
    sid = "EcrPull"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }

  statement {
    sid = "LogsBasic"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }

  # Optional S3 access for data/artifacts (scoped if ARNs provided)
  dynamic "statement" {
    for_each = length(var.s3_bucket_arns) > 0 ? [1] : []
    content {
      sid = "S3AccessScoped"
      actions = [
        "s3:GetObject", "s3:PutObject", "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      resources = var.s3_bucket_arns
    }
  }
}

resource "aws_iam_role_policy" "inline" {
  name   = "${var.project_prefix}-ec2-inline"
  role   = aws_iam_role.ec2_ssm_role.id
  policy = data.aws_iam_policy_document.inline.json
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.project_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
