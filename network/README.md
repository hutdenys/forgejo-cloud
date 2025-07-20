# Network Infrastructure Module

This module creates the VPC and networking infrastructure for the Forgejo application using the AWS VPC Terraform module.

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

- `aws_region`: AWS region for deployment
- `project_name`: Name to prefix resources with
- `environment`: Environment name (e.g. dev, prod)
- `vpc_cidr`: CIDR block for the VPC
- `azs`: List of availability zones
- `public_subnets`: List of public subnet CIDRs
- `private_subnets`: List of private subnet CIDRs
- `enable_nat_gateway`: Whether to enable NAT gateway for private subnets

## Outputs

- `vpc_id`: ID of the created VPC
- `public_subnets`: List of public subnet IDs
- `private_subnets`: List of private subnet IDs

## Resources Created

- VPC with public and private subnets
- Internet Gateway
- NAT Gateway (if enabled)
- Route tables and associations
- DNS resolution enabled

## Important Notes

- This module should be deployed first as other modules depend on its outputs
- NAT Gateway is configured as single gateway to reduce costs
- DNS hostnames are enabled for proper service discovery
