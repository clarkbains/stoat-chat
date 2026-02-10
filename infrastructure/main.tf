terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration - update after running oidc-setup
  # Uncomment and configure after OIDC setup is complete
  backend "s3" {
    bucket         = "stoat-terraform-state-081807372835"
    key            = "stoat-chat/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "stoat-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "stoat-chat"
      ManagedBy = "terraform"
      Component = "infrastructure"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# New hosted zone for aws.cbains.ca
resource "aws_route53_zone" "cbains" {
  name = "aws.cbains.ca"
  
  tags = {
    Name = "cbains-aws-zone"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# VPC and Networking
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "stoat-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "stoat-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "stoat-public-subnet"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "stoat-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "stoat" {
  name        = "stoat-sg"
  description = "Security group for Stoat Chat server"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    description = "HTTP from internet (Caddy redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (conditional)
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr != "" ? [1] : []
    content {
      description = "SSH for administration"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ssh_cidr]
    }
  }

  # Egress - allow all
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "stoat-sg"
  }
}

################################################################################
# S3 Bucket for Media Storage
################################################################################

resource "aws_s3_bucket" "media" {
  bucket = var.s3_media_bucket_name != "" ? var.s3_media_bucket_name : "stoat-media-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "stoat-media"
  }
}

################################################################################
# ECR Repositories for Stoat Components
################################################################################

resource "aws_ecr_repository" "stoat_components" {
  for_each = toset([
    "server",
    "bonfire", 
    "client",
    "autumn",
    "january",
    "gifbox",
    "crond",
    "pushd"
  ])

  name                 = "stoat/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name      = "stoat-${each.key}"
    Component = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "stoat_components" {
  for_each   = aws_ecr_repository.stoat_components
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["https://${var.domain_name}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

################################################################################
# IAM Role for EC2 Instance
################################################################################

resource "aws_iam_role" "stoat_instance" {
  name = "stoat-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "stoat-instance-role"
  }
}

resource "aws_iam_policy" "stoat_s3_access" {
  name        = "stoat-s3-access-policy"
  description = "Policy for Stoat Chat to access S3 media bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.media.arn,
          "${aws_s3_bucket.media.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "stoat_route53_access" {
  name        = "stoat-route53-access-policy"
  description = "Policy for Caddy to manage Route53 DNS records for ACME challenges"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::change/*",
          aws_route53_zone.cbains.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "stoat_ecr_access" {
  name        = "stoat-ecr-access-policy"
  description = "Policy for EC2 instance to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "stoat_s3_access" {
  role       = aws_iam_role.stoat_instance.name
  policy_arn = aws_iam_policy.stoat_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "stoat_route53_access" {
  role       = aws_iam_role.stoat_instance.name
  policy_arn = aws_iam_policy.stoat_route53_access.arn
}

resource "aws_iam_role_policy_attachment" "stoat_ecr_access" {
  role       = aws_iam_role.stoat_instance.name
  policy_arn = aws_iam_policy.stoat_ecr_access.arn
}

# Optional: CloudWatch logs
resource "aws_iam_role_policy_attachment" "stoat_cloudwatch" {
  role       = aws_iam_role.stoat_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "stoat" {
  name = "stoat-instance-profile"
  role = aws_iam_role.stoat_instance.name
}

################################################################################
# Key Pair (conditional)
################################################################################

resource "aws_key_pair" "stoat" {
  count      = var.key_pair_name != "" ? 1 : 0
  key_name   = var.key_pair_name
  public_key = file("~/.ssh/${var.key_pair_name}.pub")

  tags = {
    Name = var.key_pair_name
  }
}

################################################################################
# EC2 Instance
################################################################################

resource "aws_eip" "stoat" {
  domain = "vpc"

  tags = {
    Name = "stoat-eip"
  }
}

resource "aws_eip_association" "stoat" {
  instance_id   = aws_instance.stoat.id
  allocation_id = aws_eip.stoat.id
}

resource "aws_instance" "stoat" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.stoat.id]
  iam_instance_profile   = aws_iam_instance_profile.stoat.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    domain_name         = var.domain_name
    s3_bucket_name      = aws_s3_bucket.media.id
    s3_region           = var.aws_region
    aws_region          = var.aws_region
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 3
  }

  tags = {
    Name = "stoat-chat-server"
  }

  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}

################################################################################
# Route53 DNS
################################################################################

resource "aws_route53_record" "stoat" {
  zone_id = aws_route53_zone.cbains.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 60
  records = [aws_eip.stoat.public_ip]
}


