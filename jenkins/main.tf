provider "aws" {
  region = var.aws_region
}

# Remote state для мережі
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate random suffix for unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Security Group для Jenkins
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg-${random_string.suffix.result}"
  description = "Jenkins access from specific IP only"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Jenkins UI (тільки ваш IP)
  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip_cidr]
  }

  # SSH (тільки ваш IP)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip_cidr]
  }

  # Весь вихідний трафік
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

# EBS Volume для Jenkins Home
resource "aws_ebs_volume" "jenkins_home" {
  availability_zone = "${var.aws_region}a"
  size              = var.jenkins_home_size
  type              = "gp3"
  encrypted         = true
  iops              = 3000
  throughput        = 125

  tags = {
    Name = "jenkins-home"
  }
}

# EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  subnet_id              = data.terraform_remote_state.network.outputs.public_subnets[0]
  availability_zone      = "${var.aws_region}a"

  # Root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    ebs_device_name = "/dev/nvme1n1"
  }))

  tags = {
    Name = "jenkins-master"
    Role = "jenkins"
  }

  depends_on = [aws_ebs_volume.jenkins_home]
}

# Attach EBS Volume
resource "aws_volume_attachment" "jenkins_home" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.jenkins_home.id
  instance_id = aws_instance.jenkins.id
}

# Elastic IP
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "jenkins-eip"
  }

  depends_on = [aws_instance.jenkins]
}
