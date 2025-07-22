# EFS File System for Forgejo Cloud
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get VPC and subnet information from network module
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "network/terraform.tfstate"
    region = var.aws_region
  }
}

# Get ECS security group from app module
data "terraform_remote_state" "app" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "app/terraform.tfstate"
    region = var.aws_region
  }
}

resource "aws_efs_file_system" "this" {
  creation_token = var.creation_token
  encrypted      = true

  tags = {
    Name        = var.name
    Environment = "prod"
    Project     = "forgejo-cloud"
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(data.terraform_remote_state.network.outputs.private_subnets)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.this.id]
}

resource "aws_security_group" "this" {
  name   = "${var.name}-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.app.outputs.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/forgejo"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.name}-ap"
  }
}
