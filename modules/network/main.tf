data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use the first N AZs deterministically
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # For a /16 VPC and newbits=4, we have 16 possible /20s (indices 0..15).
  # Allocate public indices [0..az_count-1], then private indices [az_count..(2*az_count-1)].
  # This avoids overlap and stays within bounds.
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + var.az_count)]
}


###########################
# VPC & Internet Gateway
###########################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_prefix}-vpc"
    Project     = var.project_prefix
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name        = "${var.project_prefix}-igw"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

###########################
# Subnets
###########################

resource "aws_subnet" "public" {
  for_each                = { for idx, az in local.azs : idx => az }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[tonumber(each.key)]
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_prefix}-public-${each.value}"
    Tier        = "public"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

resource "aws_subnet" "private" {
  for_each          = { for idx, az in local.azs : idx => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[tonumber(each.key)]
  availability_zone = each.value

  tags = {
    Name        = "${var.project_prefix}-private-${each.value}"
    Tier        = "private"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

###########################
# NAT (single, cost-aware)
###########################

resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"
  tags = {
    Name        = "${var.project_prefix}-nat-eip"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public["0"].id # place NAT in the first public subnet

  tags = {
    Name        = "${var.project_prefix}-natgw"
    Project     = var.project_prefix
    Environment = "prod"
  }

  depends_on = [aws_internet_gateway.igw]
}

###########################
# Route Tables
###########################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name        = "${var.project_prefix}-public-rt"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags = {
    Name        = "${var.project_prefix}-private-rt-${each.key}"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

# Private subnets route either via NAT (if enabled) or remain isolated (if disabled)
resource "aws_route" "private_default" {
  for_each               = var.create_nat_gateway ? aws_route_table.private : {}
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

###########################
# Security Groups (baseline)
###########################

# Public ALB SG: allow 80/443 from the Internet; egress all
resource "aws_security_group" "alb" {
  name        = "${var.project_prefix}-alb-sg"
  description = "ALB ingress 80/443 from Internet"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_prefix}-alb-sg"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

resource "aws_security_group_rule" "alb_http_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_https_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# App SG: allow web/streamlit/fastapi (3000, 8501) from ALB only; egress all
resource "aws_security_group" "app" {
  name        = "${var.project_prefix}-app-sg"
  description = "App ingress from ALB only"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_prefix}-app-sg"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

resource "aws_security_group_rule" "app_from_alb_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_from_alb_8501" {
  type                     = "ingress"
  from_port                = 8501
  to_port                  = 8501
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
}

# Airflow SG: default has NO public ingress (use SSM); optionally allow admin CIDRs to 8080
resource "aws_security_group" "airflow" {
  name        = "${var.project_prefix}-airflow-sg"
  description = "Airflow nodes; default no public ingress"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_prefix}-airflow-sg"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

# Optional controlled admin access (8080) if CIDRs are provided
resource "aws_security_group_rule" "airflow_admin" {
  for_each          = length(var.allowed_admin_cidrs) > 0 ? toset(var.allowed_admin_cidrs) : toset([])
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.airflow.id
}

###########################
# VPC Endpoints (cost & privacy)
###########################

# S3 Gateway endpoint (no SG required)
resource "aws_vpc_endpoint" "s3" {
  count             = var.create_vpc_endpoints ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private["0"].id] # attach at least to one private RT
  tags = {
    Name        = "${var.project_prefix}-vpce-s3"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

# Shared SG for interface endpoints (allow 443 from private subnets)
resource "aws_security_group" "endpoints" {
  count  = var.create_vpc_endpoints ? 1 : 0
  name   = "${var.project_prefix}-endpoints-sg"
  vpc_id = aws_vpc.this.id

  # Ingress 443 from private CIDRs
  dynamic "ingress" {
    for_each = var.create_vpc_endpoints ? toset(local.private_subnet_cidrs) : toset([])
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_prefix}-endpoints-sg"
    Project     = var.project_prefix
    Environment = "prod"
  }
}

# Core interface endpoints to reduce NAT dependence
locals {
  interface_services = [
    "ecr.api",
    "ecr.dkr",
    "logs",
    "ssm",
    "ssmmessages",
    "ec2messages"
    # Add "monitoring" if you use CloudWatch agent scraping API
  ]
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each           = var.create_vpc_endpoints ? toset(local.interface_services) : toset([])
  vpc_id             = aws_vpc.this.id
  service_name       = "com.amazonaws.${data.aws_region.current.id}.${each.key}"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for s in aws_subnet.private : s.id]
  security_group_ids = var.create_vpc_endpoints ? [aws_security_group.endpoints[0].id] : []

  private_dns_enabled = true

  tags = {
    Name        = "${var.project_prefix}-vpce-${each.key}"
    Project     = var.project_prefix
    Environment = "prod"
  }
}
