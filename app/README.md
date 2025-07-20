# Application Module

This module deploys the Forgejo application on AWS ECS Fargate with Application Load Balancer, EFS storage, and all necessary security configurations.

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

- `forgejo_image`: Docker image for Forgejo application

## Outputs

- `alb_dns_name`: DNS name of the Application Load Balancer
- `ecs_cluster_name`: Name of the ECS cluster
- `ecs_service_name`: Name of the ECS service

## Resources Created

- **ECS Infrastructure:**
  - ECS Cluster
  - ECS Task Definition with Fargate
  - ECS Service with desired count of 1
  
- **Load Balancer:**
  - Application Load Balancer
  - Target Group for health checks
  - HTTP (port 80) and HTTPS (port 443) listeners
  - HTTP to HTTPS redirect
  
- **Security:**
  - Security groups for ALB and ECS
  - IAM roles for ECS execution and tasks
  - ECS Exec permissions for debugging
  
- **Storage:**
  - EFS integration for persistent data

## Dependencies

- Requires `network` module for VPC and subnets
- Requires `db` module for database connectivity
- Requires `acm` module for SSL certificate
- Uses `efs` module for persistent storage

## Important Notes

- Application runs on Fargate with 512 CPU and 1024 MB memory
- ECS Exec is enabled for container debugging
- Health checks configured for path "/fake" expecting 404 response
- HTTPS redirect is automatic from HTTP
- Persistent data stored in EFS mounted at `/data`
- Service runs in public subnets with public IP for ALB access
