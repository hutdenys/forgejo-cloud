# Route 53 DNS Management Module

This module manages DNS records for the Forgejo Cloud infrastructure using AWS Route 53, providing custom domain access and health monitoring.

## 🌐 Purpose

Creates and manages DNS infrastructure for:
- **Forgejo Git Service**: `forgejo.pp.ua` → ALB
- **Jenkins CI/CD**: `jenkins.forgejo.pp.ua` → EC2 public IP
- **Health Monitoring**: CloudWatch alarms for service availability
- **SSL Certificate Validation**: Automatic DNS validation for ACM

## 🏗️ DNS Architecture

```
┌─────────────────────────────────────────────────────────┐
│                Route 53 Hosted Zone                    │
│                   forgejo.pp.ua                        │
├─────────────────────┬───────────────────────────────────┤
│                     │                                   │
│  A Record           │         A Record                  │
│  forgejo.pp.ua      │    jenkins.forgejo.pp.ua         │
│        │            │              │                    │
│        ▼            │              ▼                    │
│  ┌─────────────┐    │    ┌─────────────────────┐        │
│  │     ALB     │    │    │     Jenkins EC2     │        │
│  │ (HTTPS/443) │    │    │    (HTTP/8080)      │        │
│  └─────────────┘    │    └─────────────────────┘        │
└─────────────────────┴───────────────────────────────────┘
```

## 🚀 Usage

### Prerequisites

1. **Hosted Zone**: You must own and have a Route 53 hosted zone for your domain
2. **Deployed Infrastructure**: App and Jenkins modules must be deployed first
3. **Domain Registration**: Domain must be registered and nameservers pointed to Route 53

### Deployment Steps

1. **Verify prerequisites:**
```bash
# Check hosted zone exists
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`forgejo.pp.ua.`]'

# Verify app module outputs
cd ../app && terraform output alb_dns_name

# Verify Jenkins (optional)
cd ../jenkins && terraform output jenkins_public_ip
```

2. **Deploy DNS records:**
```bash
cd route53
terraform init
terraform plan
terraform apply
```

3. **Verify DNS resolution:**
```bash
# Test DNS resolution
make check-dns

# Manual testing
nslookup forgejo.pp.ua
nslookup jenkins.forgejo.pp.ua
```

## ⚙️ Configuration Variables

### Required Variables
```hcl
domain_name = "forgejo.pp.ua"              # Your registered domain
```

### Optional Variables
```hcl
# Subdomain configuration
forgejo_subdomain = ""                     # Empty for apex domain
jenkins_subdomain = "jenkins"              # Creates jenkins.domain.com

# Feature toggles
enable_jenkins_dns = true                  # Create Jenkins DNS record
enable_health_checks = true               # Create health checks
enable_cloudwatch_alarms = true           # Create monitoring alarms

# Health check configuration
health_check_failure_threshold = 3        # Failures before alarm
health_check_interval = 30                # Check interval in seconds
health_check_path = "/api/healthz"         # Health check endpoint
```

### Example terraform.tfvars
```hcl
domain_name = "forgejo.pp.ua"
forgejo_subdomain = ""                     # Use apex domain
jenkins_subdomain = "jenkins"              # jenkins.forgejo.pp.ua
enable_jenkins_dns = true
enable_health_checks = true

# Custom health check settings
health_check_failure_threshold = 2
health_check_interval = 60
```

## 📤 Outputs

### DNS Information
- `forgejo_fqdn` - Fully qualified domain name for Forgejo
- `jenkins_fqdn` - Fully qualified domain name for Jenkins (if enabled)
- `hosted_zone_id` - Route 53 hosted zone ID
- `nameservers` - Nameservers for domain configuration

### Health Check Information
- `forgejo_health_check_id` - Health check ID for Forgejo
- `jenkins_health_check_id` - Health check ID for Jenkins (if enabled)
- `cloudwatch_alarm_arns` - CloudWatch alarm ARNs for monitoring

## 🗂️ Resources Created

### DNS Records

1. **Forgejo A Record**:
```hcl
resource "aws_route53_record" "forgejo" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name                    # forgejo.pp.ua
  type    = "A"
  
  alias {
    name                   = data.terraform_remote_state.app.outputs.alb_dns_name
    zone_id               = data.terraform_remote_state.app.outputs.alb_zone_id
    evaluate_target_health = true
  }
}
```

2. **Jenkins A Record** (Optional):
```hcl
resource "aws_route53_record" "jenkins" {
  count   = var.enable_jenkins_dns ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.jenkins_subdomain}.${var.domain_name}"  # jenkins.forgejo.pp.ua
  type    = "A"
  ttl     = 300
  records = [data.terraform_remote_state.jenkins.outputs.jenkins_public_ip]
}
```

### Health Checks

1. **Forgejo Health Check**:
```hcl
resource "aws_route53_health_check" "forgejo" {
  count                           = var.enable_health_checks ? 1 : 0
  fqdn                           = var.domain_name
  port                           = 443
  type                           = "HTTPS"
  resource_path                  = var.health_check_path
  failure_threshold              = var.health_check_failure_threshold
  request_interval               = var.health_check_interval
  cloudwatch_logs_region         = "us-east-1"
  cloudwatch_alarm_region        = "us-east-1"
  insufficient_data_health_status = "Failure"
}
```

2. **CloudWatch Alarms**:
```hcl
resource "aws_cloudwatch_metric_alarm" "forgejo_health" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "forgejo-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors forgejo health check"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
}
```

## 🎯 Dependencies

### Required Modules
1. **app** - ALB DNS name and zone ID for Forgejo record
2. **jenkins** - Public IP address for Jenkins record (optional)

### Remote State Dependencies
```hcl
# App module for ALB information
data "terraform_remote_state" "app" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "app/terraform.tfstate"
    region = "us-east-1"
  }
}

# Jenkins module for public IP (optional)
data "terraform_remote_state" "jenkins" {
  count   = var.enable_jenkins_dns ? 1 : 0
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "jenkins/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### External Dependencies
- **Hosted Zone**: Must exist in Route 53 before deployment
- **Domain Registration**: Domain must be registered and nameservers configured

## 📊 Monitoring & Alerting

### Health Check Monitoring

Route 53 health checks monitor:
- **Endpoint Availability**: HTTP/HTTPS response codes
- **Response Time**: Latency monitoring
- **Global Monitoring**: Checks from multiple AWS regions
- **SSL Certificate**: Certificate validity monitoring

### CloudWatch Integration

```bash
# View health check metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Route53 \
  --metric-name HealthCheckStatus \
  --dimensions Name=HealthCheckId,Value=xxxxx \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

### SNS Notifications

```hcl
# Optional: Create SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  name  = "forgejo-health-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.enable_cloudwatch_alarms ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}
```

## 🔍 Troubleshooting

### DNS Resolution Issues

1. **Check Hosted Zone**:
```bash
# Verify hosted zone exists
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`forgejo.pp.ua.`]'

# Check nameservers
aws route53 get-hosted-zone \
  --id Z1D633PJN98FT9 \
  --query 'DelegationSet.NameServers'
```

2. **Test DNS Resolution**:
```bash
# Test from different locations
nslookup forgejo.pp.ua 8.8.8.8
nslookup forgejo.pp.ua 1.1.1.1

# Check propagation
dig +trace forgejo.pp.ua
```

3. **Verify Records**:
```bash
# List all records in hosted zone
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1D633PJN98FT9
```

### Health Check Issues

1. **Failed Health Checks**:
```bash
# Check health check status
aws route53 get-health-check \
  --health-check-id xxxxx

# Get failure reason
aws route53 get-health-check-status \
  --health-check-id xxxxx
```

2. **SSL Certificate Issues**:
```bash
# Test SSL certificate
openssl s_client -connect forgejo.pp.ua:443 -servername forgejo.pp.ua

# Check certificate expiration
echo | openssl s_client -connect forgejo.pp.ua:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### Common Solutions

```bash
# Force DNS cache refresh
sudo systemctl flush-dns  # Linux
sudo dscacheutil -flushcache  # macOS

# Test health check endpoint
curl -I https://forgejo.pp.ua/api/healthz

# Verify ALB target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:account:targetgroup/forgejo/xxxxx
```

## 💰 Cost Information

### Route 53 Pricing
- **Hosted Zone**: $0.50/month per hosted zone
- **DNS Queries**: $0.40 per million queries
- **Health Checks**: $0.50/month per health check
- **Total Estimated**: ~$2-3/month for typical usage

### Cost Optimization
```hcl
# Disable health checks for development
enable_health_checks = false
enable_cloudwatch_alarms = false

# Use longer TTL for less critical records
ttl = 3600  # 1 hour instead of 5 minutes
```

## 🔧 Advanced Configuration

### Multiple Environments

```hcl
# Development environment
domain_name = "dev.forgejo.pp.ua"
forgejo_subdomain = ""

# Staging environment  
domain_name = "staging.forgejo.pp.ua"
forgejo_subdomain = ""

# Production environment
domain_name = "forgejo.pp.ua"
forgejo_subdomain = ""
```

### Custom Health Checks

```hcl
# Custom health check for API endpoint
resource "aws_route53_health_check" "api" {
  fqdn                           = "forgejo.pp.ua"
  port                           = 443
  type                           = "HTTPS"
  resource_path                  = "/api/v1/version"
  failure_threshold              = 3
  request_interval               = 30
  cloudwatch_logs_region         = "us-east-1"
  search_string                  = "version"
  cloudwatch_alarm_region        = "us-east-1"
  insufficient_data_health_status = "Failure"
}
```

### Geo-routing (Advanced)

```hcl
# Geo-routing for global users
resource "aws_route53_record" "forgejo_us" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  set_identifier = "US"
  geolocation_routing_policy {
    country = "US"
  }
  
  alias {
    name    = data.terraform_remote_state.app.outputs.alb_dns_name
    zone_id = data.terraform_remote_state.app.outputs.alb_zone_id
    evaluate_target_health = true
  }
}
```

## 💡 Important Notes

- **Deploy Last**: Route 53 should be deployed after app and jenkins modules
- **Domain Ownership**: Ensure you own the domain and have Route 53 hosted zone
- **Nameservers**: Update domain registrar to use Route 53 nameservers
- **SSL Certificates**: DNS records help with ACM certificate validation
- **Global Service**: Route 53 is a global service (no region restriction)
- **State Storage**: Terraform state in S3: `route53/terraform.tfstate`

## 🔄 Integration Examples

### ACM Certificate Validation

```hcl
# Route 53 records automatically validate ACM certificates
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}
```

### Multi-Region Setup

```hcl
# Primary region (us-east-1)
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }
  
  alias {
    name    = data.terraform_remote_state.app.outputs.alb_dns_name
    zone_id = data.terraform_remote_state.app.outputs.alb_zone_id
    evaluate_target_health = true
  }
}
```

2. **Configure variables:**
   ```bash
   # Edit terraform.tfvars with your domain and settings
   vim terraform.tfvars
   ```

3. **Deploy Route 53 module:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Outputs

After deployment, the module provides:

- `forgejo_fqdn`: Full domain name for Forgejo (e.g., git.example.com)
- `jenkins_fqdn`: Full domain name for Jenkins (if enabled)
- `hosted_zone_id`: Route 53 hosted zone ID

## DNS Propagation

After deployment, it may take some time for DNS changes to propagate:
- **TTL**: Records use appropriate TTL values for balance of performance and flexibility
- **Propagation**: Global DNS propagation typically takes 5-60 minutes
- **Verification**: Use `nslookup` or `dig` to verify DNS resolution

### DNS Verification

```bash
# Check DNS resolution
nslookup yourdomain.com

# Verify health check
curl -I https://yourdomain.com/api/healthz

# Check Route 53 records
aws route53 list-resource-record-sets --hosted-zone-id ZXXXXXXXXXXXXX
```

## Security Notes

- DNS records are public by design
- Health checks originate from AWS IP ranges
- Ensure ALB security groups allow health check traffic
- Consider using DNSSEC for additional security

## Integration with Other Modules

The Route 53 module integrates with:
- **App Module**: Gets ALB DNS name and zone ID
- **Jenkins Module**: Gets public IP for DNS record
- **ACM Module**: Works together for SSL certificate validation