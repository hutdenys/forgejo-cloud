provider "aws" {
  region = "us-east-1"
}

resource "aws_acm_certificate" "forgejo" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "forgejo-certificate"
  }
}
