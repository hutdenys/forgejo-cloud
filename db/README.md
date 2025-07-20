# Database Module

This module creates an RDS MySQL database instance for the Forgejo application using the AWS RDS Terraform module.

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

- `db_name`: Database name for the application
- `db_username`: Master username for the database
- `db_password`: Master password for the database (sensitive)
- `db_instance_class`: RDS instance class (default: "db.t3.micro")

## Outputs

- `db_endpoint`: RDS instance endpoint
- `db_port`: Database port
- `db_name`: Database name

## Resources Created

- RDS MySQL instance
- DB subnet group for private subnets
- Security group allowing MySQL access
- Automated backups and maintenance

## Dependencies

- Requires `network` module to be deployed first
- Uses remote state from network module for VPC and subnet information

## Important Notes

- Database is deployed in private subnets for security
- Current security group allows access from 0.0.0.0/0 - should be restricted to ECS security group
- Automated backups are enabled
- Database credentials should be managed securely (consider AWS Secrets Manager)
