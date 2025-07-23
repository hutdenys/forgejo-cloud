# ALB Module
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.17.0"

  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"

  vpc_id  = var.vpc_id
  subnets = var.subnets

  security_groups            = [var.alb_security_group_id]
  enable_deletion_protection = false

  target_groups = {
    forgejo = {
      name_prefix      = var.target_group_prefix
      backend_protocol = "HTTP"
      backend_port     = var.container_port
      target_type      = "ip"

      create_attachment = false

      health_check = var.health_check
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.certificate_arn

      forward = {
        target_group_key = "forgejo"
      }
    }
  }

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}
