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
  for_each = toset(data.terraform_remote_state.network.outputs.public_subnets)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [data.terraform_remote_state.network.outputs.efs_security_group_id]
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
