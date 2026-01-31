provider "aws" {
  region = "ap-south-1"  # Change to your region
}

locals {
  project_name = var.project_name
  amazon_host  = "amazon-linux"
  ubuntu_host  = "ubuntu-linux"
}

################## Security Group ##################
resource "aws_security_group" "public_sg" {
  name        = "${local.project_name}-sg"
  description = "Allow SSH, HTTP, HTTPS, ICMP from anywhere"

  dynamic "ingress" {
    for_each = var.sg_ports
    content {
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["protocol"]
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = var.sg_ports
    content {
      from_port   = egress.value["port"]
      to_port     = egress.value["port"]
      protocol    = egress.value["protocol"]
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    Name = local.project_name
  }
}

################## IAM Role for SSM ##################
resource "aws_iam_role" "ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm_instance_profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


################## Amazon Linux Instances ##################
resource "aws_instance" "amazon_linux_host" {
  count                = var.amazon_linux_host_count
  ami                  = data.aws_ami.amazon_linux_ami.id
  instance_type        = var.instance_type
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "${local.amazon_host}-${count.index + 1}"
    OS   = local.amazon_host
    SSM  = "true"
    Monitoring = "CloudWatch"
  }
}

################## Ubuntu Instances ##################
resource "aws_instance" "ubuntu_host" {
  count                = var.ubuntu_host_count
  ami                  = data.aws_ami.ubuntu_ami.id
  instance_type        = var.instance_type
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              snap install amazon-ssm-agent --classic || true
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOF

  tags = {
    Name = "${local.ubuntu_host}-${count.index + 1}"
    OS   = local.ubuntu_host
    SSM  = "true"
    Monitoring = "CloudWatch"
  }
}


