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
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.jenkins_security_group_id]
  subnet_id              = data.terraform_remote_state.network.outputs.public_subnets[0]
  availability_zone      = "${var.aws_region}a"

  # Root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
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
