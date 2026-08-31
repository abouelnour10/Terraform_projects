locals {
  ecr_policies = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
}

resource "aws_iam_role" "ec2_container" {
  name = "ec2-container"

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
}

resource "aws_iam_role_policy_attachment" "ecr" {
  for_each = local.ecr_policies

  role       = aws_iam_role.ec2_container.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ec2_container" {
  name = "ec2-container-profile"
  role = aws_iam_role.ec2_container.name
}

data "aws_vpc" "existing" {
  default = true
}

data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

data "aws_ami" "amazon_linux_2023" {

  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
resource "aws_instance" "container" {

  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.micro"
  subnet_id            = data.aws_subnets.existing.ids[0]
  iam_instance_profile = aws_iam_instance_profile.ec2_container.name
  tags = {
    Name = "ec2-container"
  }
}