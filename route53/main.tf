# Route 53 DNS Management for Forgejo Cloud
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create hosted zone for external domain
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name        = "Forgejo ${var.domain_name}"
    Environment = var.environment
    Project     = "forgejo-cloud"
  }
}

# Data source to get existing hosted zone (if not creating new)
data "aws_route53_zone" "main" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

# Use existing or created hosted zone
locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
}

# Get ALB DNS name from app module
data "terraform_remote_state" "app" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "app/terraform.tfstate"
    region = var.aws_region
  }
}

# Get Jenkins public IP from jenkins module (optional)
data "terraform_remote_state" "jenkins" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "jenkins/terraform.tfstate"
    region = var.aws_region
  }

  # Jenkins module might not exist yet
  count = var.enable_jenkins_dns ? 1 : 0
}

# A record for Forgejo application pointing to ALB
resource "aws_route53_record" "forgejo" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.app.outputs.alb_dns_name
    zone_id                = data.terraform_remote_state.app.outputs.alb_zone_id
    evaluate_target_health = false
  }
}

# A record for Jenkins (if enabled)
resource "aws_route53_record" "jenkins" {
  count   = var.enable_jenkins_dns ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "${var.jenkins_subdomain}.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [data.terraform_remote_state.jenkins[0].outputs.jenkins_public_ip]
}
