# EFS (Elastic File System) Module

This module creates an encrypted EFS file system with mount targets and access points for persistent storage in the Forgejo application.

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

- `name`: Name prefix for EFS resources
- `creation_token`: Unique token for EFS creation
- `vpc_id`: VPC ID where EFS will be created
- `subnet_ids`: List of subnet IDs for mount targets
- `ecs_security_group_id`: Security group ID for ECS tasks to access EFS

## Outputs

- `file_system_id`: ID of the created EFS file system
- `access_point_id`: ID of the EFS access point
- `mount_target_ids`: List of mount target IDs

## Resources Created

- Encrypted EFS file system
- Mount targets in specified subnets
- EFS access point with POSIX permissions
- Security group allowing NFS access from ECS

## Dependencies

- Requires VPC and subnets to be created first
- Requires ECS security group to be available

## Important Notes

- File system is encrypted at rest for security
- Mount targets are created in private subnets
- Access point provides consistent UID/GID for container access
- NFS traffic (port 2049) is allowed from ECS security group only
- Provides persistent storage for Forgejo data and repositories
