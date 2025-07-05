# Bastion Host for accessing private instances and webhook server
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami           = data.aws_ami.nomad.id
  instance_type = "t3.small"  # Upgraded for webhook processing
  key_name      = var.key_pair_name
  
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_webhook[0].name

  user_data = base64encode(templatefile("${path.module}/user_data_bastion.sh", {
    cluster_name = var.cluster_name
    region       = data.aws_region.current.name
  }))

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-bastion-webhook"
    Type = "bastion-webhook"
  })
}

resource "aws_security_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name_prefix = "${var.cluster_name}-bastion-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH from allowed IPs"
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # GitHub webhook IPs - consider restricting in production
    description = "Webhook server port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-bastion-webhook-sg"
  })
}

# Update security groups to allow bastion access
resource "aws_security_group_rule" "nomad_server_bastion" {
  count = var.enable_bastion ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion[0].id
  security_group_id        = aws_security_group.nomad_servers.id
  description              = "SSH from bastion"
}

resource "aws_security_group_rule" "nomad_client_bastion" {
  count = var.enable_bastion ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion[0].id
  security_group_id        = aws_security_group.nomad_clients.id
  description              = "SSH from bastion"
}

# IAM Role for Bastion Webhook Operations
resource "aws_iam_role" "bastion_webhook" {
  count = var.enable_bastion ? 1 : 0
  
  name = "${var.cluster_name}-bastion-webhook-role"

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

resource "aws_iam_policy" "bastion_webhook" {
  count = var.enable_bastion ? 1 : 0
  
  name = "${var.cluster_name}-bastion-webhook-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Terragrunt/Terraform operations
          "sts:AssumeRole",
          "sts:GetCallerIdentity",
          # S3 for Terraform state (adjust bucket ARN as needed)
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          # DynamoDB for state locking
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          # App Runner operations
          "apprunner:*",
          # ECR access for container deployments
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          # CloudWatch Logs
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLog*",
          # SSM for parameter store
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "bastion_webhook" {
  count = var.enable_bastion ? 1 : 0
  
  role       = aws_iam_role.bastion_webhook[0].name
  policy_arn = aws_iam_policy.bastion_webhook[0].arn
}

resource "aws_iam_instance_profile" "bastion_webhook" {
  count = var.enable_bastion ? 1 : 0
  
  name = "${var.cluster_name}-bastion-webhook-profile"
  role = aws_iam_role.bastion_webhook[0].name

  tags = var.common_tags
}