# ACM Certificate Module

This module creates an ACM certificate for the Forgejo application.

## Usage

1. Initialize Terraform:
```bash
terraform init
```

2. Plan the deployment:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

## Variables

- `domain_name`: Domain name for the ACM certificate (default: "forgejo.pp.ua")

## Outputs

- `certificate_arn`: ARN of the ACM certificate
- `certificate_domain_name`: Domain name of the certificate

## Important Notes

- This certificate needs to be validated via DNS
- Make sure to validate the certificate before using it in other modules
- The certificate is created in us-east-1 region as required for CloudFront/ALB
