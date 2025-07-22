# Route 53 DNS Module

This module manages DNS records for the Forgejo Cloud infrastructure using AWS Route 53.

## Overview

The Route 53 module creates and manages:
- A record for Forgejo application pointing to ALB
- Optional A record for Jenkins CI/CD
- Health checks and CloudWatch alarms for monitoring
- DNS records with proper aliases for optimal performance

## Resources Created

### DNS Records
- **Forgejo A Record**: Points domain (e.g., example.com) to ALB
- **Jenkins A Record**: Points subdomain (e.g., jenkins.example.com) to EC2 public 

## Prerequisites
1. **Existing Hosted Zone**: You must have a Route 53 hosted zone for your domain
2. **Deployed Infrastructure**: App module (and optionally Jenkins) must be deployed first
3. **S3 State Backend**: Terraform state bucket must exist

## Configuration

### Required Variables

```hcl
domain_name = "yourdomain.com"    # Your registered domain
state_bucket = "your-state-bucket" # S3 bucket for Terraform state
```

### Optional Variables

```hcl
forgejo_subdomain = "git"         # Subdomain for Forgejo (default: git)
jenkins_subdomain = "jenkins"     # Subdomain for Jenkins (default: jenkins)
enable_jenkins_dns = true         # Create Jenkins DNS record
```

## Deployment

1. **Ensure prerequisites are met:**
   ```bash
   # Verify hosted zone exists
   aws route53 list-hosted-zones --query 'HostedZones[?Name==`yourdomain.com.`]'
   
   # Verify app module is deployed
   cd ../app && terraform output alb_dns_name
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