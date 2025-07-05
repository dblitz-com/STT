terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.20"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# VPC and Networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 100)]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_vpc_flow_logs

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# Security Groups
resource "aws_security_group" "nomad_servers" {
  name_prefix = "${var.cluster_name}-servers-"
  vpc_id      = module.vpc.vpc_id

  # Nomad Server Ports
  ingress {
    from_port   = 4646
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Nomad HTTP/RPC/Serf"
  }

  # Consul Ports
  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Consul Server/Serf/LAN"
  }

  ingress {
    from_port   = 8500
    to_port     = 8502
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Consul HTTP/HTTPS/gRPC"
  }

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH Access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-servers-sg"
  })
}

resource "aws_security_group" "nomad_clients" {
  name_prefix = "${var.cluster_name}-clients-"
  vpc_id      = module.vpc.vpc_id

  # Nomad Client Ports
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Nomad HTTP"
  }

  # Dynamic Port Range for Tasks
  ingress {
    from_port   = 20000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Nomad Dynamic Ports"
  }

  # Application Load Balancer
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTPS from ALB"
  }

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH Access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-clients-sg"
  })
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.cluster_name}-alb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-alb-sg"
  })
}

# IAM Roles and Policies
resource "aws_iam_role" "nomad_server" {
  name = "${var.cluster_name}-nomad-server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role" "nomad_client" {
  name = "${var.cluster_name}-nomad-client"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# IAM Policies
resource "aws_iam_policy" "nomad_server" {
  name = "${var.cluster_name}-nomad-server-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeNetworkInterfaces",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLog*",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "nomad_client" {
  name = "${var.cluster_name}-nomad-client-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeSnapshots",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLog*",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "kms:Decrypt",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "nomad_server" {
  role       = aws_iam_role.nomad_server.name
  policy_arn = aws_iam_policy.nomad_server.arn
}

resource "aws_iam_role_policy_attachment" "nomad_client" {
  role       = aws_iam_role.nomad_client.name
  policy_arn = aws_iam_policy.nomad_client.arn
}

# Instance Profiles
resource "aws_iam_instance_profile" "nomad_server" {
  name = "${var.cluster_name}-nomad-server"
  role = aws_iam_role.nomad_server.name

  tags = var.common_tags
}

resource "aws_iam_instance_profile" "nomad_client" {
  name = "${var.cluster_name}-nomad-client"
  role = aws_iam_role.nomad_client.name

  tags = var.common_tags
}

# Launch Templates
resource "aws_launch_template" "nomad_server" {
  name_prefix   = "${var.cluster_name}-server-"
  image_id      = data.aws_ami.nomad.id
  instance_type = var.server_instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.nomad_servers.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.nomad_server.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data_server.sh", {
    cluster_name      = var.cluster_name
    region            = data.aws_region.current.name
    consul_enabled    = var.consul_enabled
    vault_enabled     = var.vault_enabled
    vault_address     = var.vault_address
    server_count      = var.server_count
    enable_monitoring = var.enable_monitoring
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 50
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "nomad_client" {
  name_prefix   = "${var.cluster_name}-client-"
  image_id      = data.aws_ami.nomad.id
  instance_type = var.client_instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.nomad_clients.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.nomad_client.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data_client.sh", {
    cluster_name       = var.cluster_name
    region            = data.aws_region.current.name
    consul_enabled    = var.consul_enabled
    enable_csi_drivers = var.enable_csi_drivers
    enable_monitoring  = var.enable_monitoring
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 100
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Groups
resource "aws_autoscaling_group" "nomad_servers" {
  name                = "${var.cluster_name}-servers"
  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = var.enable_alb ? [aws_lb_target_group.nomad_ui[0].arn] : []
  health_check_type   = "ELB"
  min_size            = var.server_count
  max_size            = var.server_count
  desired_capacity    = var.server_count

  launch_template {
    id      = aws_launch_template.nomad_server.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-server"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

resource "aws_autoscaling_group" "nomad_clients" {
  name                = "${var.cluster_name}-clients"
  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = var.enable_alb ? [aws_lb_target_group.gengine_api[0].arn] : []
  health_check_type   = "ELB"
  min_size            = var.enable_autoscaling ? var.min_client_nodes : var.client_count
  max_size            = var.enable_autoscaling ? var.max_client_nodes : var.client_count
  desired_capacity    = var.client_count

  launch_template {
    id      = aws_launch_template.nomad_client.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-client"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 75
    }
  }
}

# Application Load Balancer
resource "aws_lb" "nomad" {
  count = var.enable_alb ? 1 : 0

  name               = "${var.cluster_name}-alb"
  internal           = var.enable_internal_alb
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.enable_internal_alb ? module.vpc.private_subnets : module.vpc.public_subnets

  enable_deletion_protection = false

  # Temporarily disable access logs to fix permissions issue
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs[0].bucket
  #   prefix  = "alb"
  #   enabled = true
  # }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-alb"
  })
}

# Target Groups
resource "aws_lb_target_group" "nomad_ui" {
  count = var.enable_alb ? 1 : 0

  name     = "${var.cluster_name}-nomad-ui"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/ui/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = var.common_tags
}

resource "aws_lb_target_group" "gengine_api" {
  count = var.enable_alb ? 1 : 0

  name     = "${var.cluster_name}-gengine-api"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = var.common_tags
}

# ALB Listeners
resource "aws_lb_listener" "http" {
  count = var.enable_alb ? 1 : 0

  load_balancer_arn = aws_lb.nomad[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad_ui[0].arn
  }
}

# Listener rule for API endpoints
resource "aws_lb_listener_rule" "gengine_api" {
  count = var.enable_alb ? 1 : 0

  listener_arn = aws_lb_listener.http[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gengine_api[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/health", "/docs"]
    }
  }
}

# S3 Bucket for ALB Logs
resource "aws_s3_bucket" "alb_logs" {
  count = var.enable_alb ? 1 : 0

  bucket        = "${var.cluster_name}-alb-logs-${random_id.bucket_suffix[0].hex}"
  force_destroy = true

  tags = var.common_tags
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.enable_alb ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.enable_alb ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_id" "bucket_suffix" {
  count = var.enable_alb ? 1 : 0

  byte_length = 8
}

# Get AMI
data "aws_ami" "nomad" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# SSL Certificate
resource "aws_acm_certificate" "nomad" {
  count = var.enable_alb && var.route53_zone_id != "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}",
    "nomad.${var.domain_name}",
    "api.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = var.common_tags
}

# Route53 Records for SSL Validation
resource "aws_route53_record" "nomad_validation" {
  for_each = var.enable_alb && var.route53_zone_id != "" ? {
    for dvo in aws_acm_certificate.nomad[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Certificate Validation
resource "aws_acm_certificate_validation" "nomad" {
  count = var.enable_alb && var.route53_zone_id != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.nomad[0].arn
  validation_record_fqdns = [for record in aws_route53_record.nomad_validation : record.fqdn]
}

# Route53 Records
resource "aws_route53_record" "nomad_ui" {
  count = var.enable_alb && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "nomad.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.nomad[0].dns_name
    zone_id                = aws_lb.nomad[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  count = var.enable_alb && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.nomad[0].dns_name
    zone_id                = aws_lb.nomad[0].zone_id
    evaluate_target_health = true
  }
}

# App Runner Service (Simple deployment alternative)
resource "aws_apprunner_service" "gengine_api" {
  count = var.enable_app_runner ? 1 : 0

  service_name = "${var.cluster_name}-gengine-api"

  source_configuration {
    image_repository {
      image_identifier      = var.app_runner_image_uri
      image_configuration {
        port = "8000"
        runtime_environment_variables = {
          LOG_LEVEL   = var.app_runner_log_level
          ENVIRONMENT = var.cluster_name
        }
      }
      image_repository_type = "ECR"
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_access[0].arn
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu    = var.app_runner_cpu
    memory = var.app_runner_memory
    instance_role_arn = aws_iam_role.app_runner_instance[0].arn
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  tags = var.common_tags
}

# App Runner access role for ECR authentication
resource "aws_iam_role" "app_runner_access" {
  count = var.enable_app_runner ? 1 : 0
  
  name = "${var.cluster_name}-app-runner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "app_runner_access" {
  count = var.enable_app_runner ? 1 : 0
  
  role       = aws_iam_role.app_runner_access[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# App Runner instance role (for runtime permissions)
resource "aws_iam_role" "app_runner_instance" {
  count = var.enable_app_runner ? 1 : 0
  
  name = "${var.cluster_name}-app-runner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}