# ELB (Application Load Balancer) Module

This submodule creates a production-ready Application Load Balancer with SSL termination, HTTP to HTTPS redirect, and comprehensive health monitoring for the Forgejo application.

## 🏗️ Architecture

```
                    Internet
                        │
                ┌───────▼───────┐
                │      ALB      │
                │ (Public IPs)  │
                └───┬───────┬───┘
                    │       │
             HTTP:80│       │HTTPS:443
                    │       │
            ┌───────▼───────▼───────┐
            │   Target Group        │
            │  (Health Checks)      │
            └───────┬───────────────┘
                    │
            ┌───────▼───────┐
            │   ECS Tasks   │
            │   Port 3000   │
            └───────────────┘
```

## 🎯 Features

- **SSL Termination**: HTTPS encryption with ACM certificate
- **HTTP Redirect**: Automatic redirect from HTTP to HTTPS
- **Health Checks**: Configurable application health monitoring
- **Multi-AZ**: Load balancing across multiple availability zones
- **Security Groups**: Proper ingress/egress rules
- **Access Logs**: Optional ALB access logging to S3

## 🚀 Usage

This module is designed as a submodule within the app module:

```hcl
module "elb" {
  source = "./modules/elb"

  name_prefix     = "forgejo"
  vpc_id          = var.vpc_id
  subnets         = var.public_subnets
  certificate_arn = var.certificate_arn
  
  # Optional customization
  container_port = 3000
  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/healthz"
    matcher             = "200"
  }
}
```

## ⚙️ Variables

### Required Variables
- `name_prefix` - Name prefix for resources (e.g., "forgejo")
- `vpc_id` - VPC ID where ALB will be created
- `subnets` - List of public subnet IDs for ALB placement
- `certificate_arn` - ARN of the SSL certificate for HTTPS

### Optional Variables
```hcl
# Application configuration
container_port = 3000                    # Port container listens on
target_group_prefix = "fgj"              # Target group name prefix (max 6 chars)

# Health check configuration
health_check = {
  enabled             = true
  healthy_threshold   = 2               # Consecutive successes to mark healthy
  unhealthy_threshold = 2               # Consecutive failures to mark unhealthy
  timeout             = 5               # Health check timeout (2-120 seconds)
  interval            = 30              # Health check interval (5-300 seconds)
  path                = "/api/healthz"  # Health check endpoint
  matcher             = "200"           # Success response codes
  port                = "traffic-port"  # Port for health checks
  protocol            = "HTTP"          # Health check protocol
}

# Access logging (optional)
enable_access_logs = false              # Enable ALB access logs
access_logs_bucket = ""                 # S3 bucket for access logs
access_logs_prefix = "alb-logs"         # S3 prefix for logs

# Tags
tags = {
  Environment = "prod"
  Project     = "forgejo"
}
```

## 📤 Outputs

### Load Balancer Information
- `alb_arn` - ARN of the Application Load Balancer
- `alb_dns_name` - DNS name of the ALB (for Route 53)
- `alb_zone_id` - Zone ID of the ALB (for Route 53 alias records)
- `alb_hosted_zone_id` - Hosted zone ID for DNS records

### Target Group Information
- `target_group_arn` - ARN of the target group (used by ECS)
- `target_group_name` - Name of the target group

### Security Group Information
- `alb_security_group_id` - Security group ID for ALB (used by ECS module)

## 🗂️ Resources Created

### Application Load Balancer
```hcl
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  subnets            = var.subnets
  security_groups    = [aws_security_group.alb.id]
  
  enable_deletion_protection = false
  enable_http2              = true
  idle_timeout              = 60
  
  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
    enabled = var.enable_access_logs
  }
}
```

### Target Group
```hcl
resource "aws_lb_target_group" "main" {
  name     = "${var.target_group_prefix}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  target_type = "ip"  # For ECS Fargate
  
  health_check {
    enabled             = var.health_check.enabled
    healthy_threshold   = var.health_check.healthy_threshold
    unhealthy_threshold = var.health_check.unhealthy_threshold
    timeout             = var.health_check.timeout
    interval            = var.health_check.interval
    path                = var.health_check.path
    matcher             = var.health_check.matcher
    port                = var.health_check.port
    protocol            = var.health_check.protocol
  }
  
  # Ensure smooth deployments
  lifecycle {
    create_before_destroy = true
  }
}
```

### Listeners

1. **HTTPS Listener (443)**:
```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

2. **HTTP Listener (80)** - Redirect to HTTPS:
```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

### Security Group
```hcl
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To application"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
}
```

## 📊 Health Check Configuration

### Default Health Check
```hcl
health_check = {
  enabled             = true
  healthy_threshold   = 2
  unhealthy_threshold = 2
  timeout             = 5
  interval            = 30
  path                = "/api/healthz"
  matcher             = "200"
  port                = "traffic-port"
  protocol            = "HTTP"
}
```

### Custom Health Check Examples
```hcl
# Strict health check
health_check = {
  enabled             = true
  healthy_threshold   = 3
  unhealthy_threshold = 2
  timeout             = 3
  interval            = 15
  path                = "/health"
  matcher             = "200,204"
  port                = "traffic-port"
  protocol            = "HTTP"
}

# Relaxed health check
health_check = {
  enabled             = true
  healthy_threshold   = 2
  unhealthy_threshold = 5
  timeout             = 10
  interval            = 60
  path                = "/"
  matcher             = "200-299"
  port                = "traffic-port"
  protocol            = "HTTP"
}
```

## 🔒 Security Features

### SSL/TLS Configuration
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01 (PCI compliant)
- **HTTP to HTTPS Redirect**: All HTTP traffic automatically redirected
- **Certificate Management**: Integrated with AWS Certificate Manager

### Security Groups
- **Inbound**: Allow HTTP (80) and HTTPS (443) from internet
- **Outbound**: Allow traffic to ECS containers only
- **Principle of Least Privilege**: Minimal required access

## 📊 Monitoring & Logging

### CloudWatch Metrics

ALB automatically provides metrics:
- **Request Count**: Total number of requests
- **Target Response Time**: Average response time
- **HTTP Error Counts**: 4xx and 5xx errors
- **Healthy Host Count**: Number of healthy targets

### Access Logs (Optional)

```hcl
# Enable access logs
enable_access_logs = true
access_logs_bucket = "my-alb-logs-bucket"
access_logs_prefix = "forgejo-alb"
```

Log format includes:
- Timestamp, client IP, target IP
- Request/response sizes
- Response codes and processing time
- User agent, SSL cipher, SSL protocol

### Custom Metrics

```bash
# Example: Monitor 5xx errors
aws cloudwatch put-metric-alarm \
  --alarm-name "ALB-High-5xx-Errors" \
  --alarm-description "High 5xx error rate" \
  --metric-name HTTPCode_ELB_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

## 🔍 Troubleshooting

### Common Issues

1. **502/503 Errors**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check ECS service health
aws ecs describe-services \
  --cluster forgejo-cluster \
  --services forgejo
```

2. **SSL Certificate Issues**:
```bash
# Verify certificate
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn)

# Test SSL connection
openssl s_client -connect $(terraform output -raw alb_dns_name):443
```

3. **Health Check Failures**:
```bash
# Test health check endpoint
curl -I http://$(terraform output -raw alb_dns_name)/api/healthz

# Check application logs
aws logs tail /ecs/forgejo --follow
```

### Debug Commands

```bash
# ALB status
aws elbv2 describe-load-balancers \
  --load-balancer-arns $(terraform output -raw alb_arn)

# Target group details
aws elbv2 describe-target-groups \
  --target-group-arns $(terraform output -raw target_group_arn)

# Listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn)
```

## 💰 Cost Optimization

### ALB Pricing Components
- **Base cost**: ~$16/month for ALB
- **LCU (Load Balancer Capacity Units)**: Based on usage
- **Data processing**: $0.008 per GB processed

### Optimization Tips
```hcl
# Use shorter health check intervals only if needed
health_check = {
  interval = 60  # Instead of 30 seconds
}

# Disable access logs if not needed
enable_access_logs = false

# Use appropriate idle timeout
idle_timeout = 60  # Default, adjust based on application needs
```

## 💡 Important Notes

- **Public Subnets**: ALB must be in public subnets to receive internet traffic
- **Certificate Validation**: Ensure ACM certificate is validated before deployment
- **Target Type**: Uses "ip" target type for ECS Fargate compatibility
- **Health Checks**: Critical for proper load balancing and auto-recovery
- **Security Groups**: ALB security group must allow outbound to ECS security group
- **Deployment**: Creates target group before destroy to enable zero-downtime deployments

## 🔄 Advanced Configuration

### Multiple Target Groups
```hcl
# Path-based routing
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
```

### Weighted Routing (Blue/Green)
```hcl
# Blue/Green deployment support
resource "aws_lb_listener_rule" "weighted" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 90
      }
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 10
      }
    }
  }
}
```

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
