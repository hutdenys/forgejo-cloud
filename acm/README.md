# ACM SSL Certificate Module

This module creates and manages SSL/TLS certificates using AWS Certificate Manager (ACM) for secure HTTPS communication.

## 🔒 Purpose

Provides SSL/TLS certificates for:
- **Forgejo Git Service**: `forgejo.pp.ua`
- **Additional domains**: Can be configured for multiple domains/subdomains

## 🚀 Usage

1. **Initialize Terraform:**
```bash
terraform init
```

2. **Plan the deployment:**
```bash
terraform plan
```

3. **Deploy certificate:**
```bash
terraform apply
```

## ⚙️ Configuration

### Variables

- `domain_name` - Primary domain name for the certificate (default: "forgejo.pp.ua")
- `subject_alternative_names` - Additional domains for multi-domain certificate (optional)
- `validation_method` - Certificate validation method (default: "DNS")

### Example terraform.tfvars

```hcl
domain_name = "forgejo.pp.ua"
subject_alternative_names = [
  "*.forgejo.pp.ua",
  "jenkins.forgejo.pp.ua"
]
```

## 📤 Outputs

- `certificate_arn` - ARN of the ACM certificate (used by ALB)
- `certificate_domain_name` - Primary domain name of the certificate
- `certificate_status` - Current status of the certificate
- `domain_validation_options` - DNS validation records (for manual validation)

## 🔧 Certificate Validation

### DNS Validation (Recommended)

The certificate uses DNS validation which requires:

1. **Automatic** (if Route 53 manages the domain):
   - Terraform automatically creates validation records
   - Certificate validates automatically

2. **Manual** (if external DNS provider):
   - Check terraform output for validation records:
     ```bash
     terraform output domain_validation_options
     ```
   - Add CNAME records to your DNS provider
   - Wait for validation (usually 5-30 minutes)

### Validation Status Check

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --region us-east-1
```

## 🎯 Dependencies

- **None** - Can be deployed independently or in parallel with network module
- **Used by**: App module (ALB requires certificate ARN for HTTPS)

## 🌍 Region Requirement

- **Must be deployed in us-east-1** region for CloudFront/Global ALB compatibility
- Certificate can be used by resources in any region

## 💡 Important Notes

- **DNS Validation**: Ensure domain ownership before requesting certificate
- **Wildcard Support**: Use `*.domain.com` for subdomain coverage
- **Free**: ACM certificates are free for AWS resources
- **Auto-Renewal**: Certificates auto-renew if validation remains valid
- **State Storage**: Terraform state in S3: `acm/terraform.tfstate`

## 🔍 Troubleshooting

### Common Issues

1. **Validation Timeout**:
   - Verify DNS records are correctly configured
   - Check domain ownership
   - DNS propagation may take time

2. **Certificate Pending**:
   ```bash
   # Check validation status
   terraform refresh
   terraform output domain_validation_options
   ```

3. **Wrong Region**:
   - Ensure certificate is created in us-east-1
   - ALB must reference certificate in the same region
