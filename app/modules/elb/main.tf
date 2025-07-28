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

    jenkins = {
      name_prefix      = "jkns"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "instance"

      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/login"
        healthy_threshold   = 2
        unhealthy_threshold = 10
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }
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

      rules = {
        jenkins = {
          priority = 100

          conditions = [{
            host_header = {
              values = [var.jenkins_domain]
            }
          }]

          actions = [{
            type             = "forward"
            target_group_key = "jenkins"
          }]
        }
      }

      forward = {
        target_group_key = "forgejo"
      }
    }
  }

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}
