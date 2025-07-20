# ELB (Application Load Balancer) Module

This module creates an Application Load Balancer with HTTP to HTTPS redirect, target groups, and security groups for the Forgejo application.

## Usage

This module is designed to be used as a submodule within the app module:

```terraform
module "elb" {
  source = "./modules/elb"

  name_prefix     = "forgejo"
  vpc_id          = var.vpc_id
  subnets         = var.public_subnets
  certificate_arn = var.certificate_arn
}
```

## Variables

- `name_prefix`: Name prefix for resources (default: "forgejo")
- `vpc_id`: VPC ID where ALB will be created
- `subnets`: List of public subnet IDs for ALB
- `certificate_arn`: ARN of the SSL certificate for HTTPS
- `container_port`: Port on which the container is listening (default: 3000)
- `target_group_prefix`: Prefix for target group name (default: "fgj")
- `health_check`: Health check configuration object with path, thresholds, etc.

## Outputs

- `alb_security_group_id`: Security group ID of the ALB
- `alb_dns_name`: DNS name of the load balancer
- `alb_zone_id`: Zone ID of the load balancer
- `target_group_arn`: ARN of the target group
- `alb_arn`: ARN of the load balancer

## Resources Created

- **Security Group**: Allows HTTP (80) and HTTPS (443) traffic from internet
- **Application Load Balancer**: Internet-facing ALB in public subnets
- **Target Group**: IP-based target group for Fargate tasks
- **Listeners**: 
  - HTTP (port 80) with redirect to HTTPS
  - HTTPS (port 443) with SSL termination

## Features

- **SSL Termination**: HTTPS traffic terminated at ALB level
- **HTTP Redirect**: Automatic redirect from HTTP to HTTPS
- **Health Checks**: Configurable health checks for backend services
- **Security**: Security group with controlled access

## Health Check Configuration

Default health check configuration:
- Path: `/fake` (expecting 404 response)
- Healthy threshold: 2
- Unhealthy threshold: 10
- Timeout: 2 seconds
- Interval: 300 seconds (5 minutes)

## Important Notes

- ALB is deployed in public subnets for internet access
- SSL certificate must be validated before use
- Target group uses IP targeting for Fargate compatibility
- Health check path should match your application's endpoint
