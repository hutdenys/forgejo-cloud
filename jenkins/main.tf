provider "aws" {
  region = var.aws_region
}

# Remote state for network
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state for persistent EBS volume
data "terraform_remote_state" "ebs_jenkins" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "ebs-jenkins/terraform.tfstate"
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

# IAM Role for Jenkins to manage EC2 instances
resource "aws_iam_role" "jenkins_ec2_role" {
  name = "jenkins-ec2-role-${random_string.suffix.result}"

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

  tags = {
    Name = "jenkins-ec2-role"
    Role = "jenkins"
  }
}

# IAM Policy for Jenkins EC2 Plugin
resource "aws_iam_policy" "jenkins_ec2_policy" {
  name        = "jenkins-ec2-policy-${random_string.suffix.result}"
  description = "Policy for Jenkins EC2 Plugin to manage spot instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSpotInstanceRequests",
          "ec2:CancelSpotInstanceRequests",
          "ec2:GetConsoleOutput",
          "ec2:RequestSpotInstances",
          "ec2:RunInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeRegions",
          "ec2:DescribeImages",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "iam:ListInstanceProfilesForRole",
          "iam:PassRole",
          "ec2:GetPasswordData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "jenkins-ec2-policy"
    Role = "jenkins"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "jenkins_ec2_attach" {
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = aws_iam_policy.jenkins_ec2_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "jenkins_ec2_profile" {
  name = "jenkins-ec2-profile-${random_string.suffix.result}"
  role = aws_iam_role.jenkins_ec2_role.name

  tags = {
    Name = "jenkins-ec2-profile"
    Role = "jenkins"
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
  iam_instance_profile   = aws_iam_instance_profile.jenkins_ec2_profile.name

  # Root volume
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    ebs_device_name = "/dev/xvdf"
  }))

  tags = {
    Name = "jenkins-master"
    Role = "jenkins"
  }
}

# Attach EBS Volume
resource "aws_volume_attachment" "jenkins_home" {
  device_name = "/dev/sdf"
  volume_id   = data.terraform_remote_state.ebs_jenkins.outputs.volume_id
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
