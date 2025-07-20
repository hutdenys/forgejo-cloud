# Application Module

This module deploys the Forgejo application on AWS ECS Fargate with Application Load Balancer, EFS storage, and all necessary security configurations. The module is organized into submodules for better maintainability.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     App Module                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │     ELB     │  │     ECS     │  │       EFS       │ │
│  │  (ALB + SG) │  │(Cluster+SG) │  │   (External)    │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

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
- `alb_zone_id`: Zone ID of the Application Load Balancer
- `ecs_cluster_name`: Name of the ECS cluster
- `ecs_service_name`: Name of the ECS service
- `task_definition_arn`: ARN of the task definition

## Submodules

### ELB Module (`./modules/elb/`)
- **Purpose**: Application Load Balancer with SSL termination
- **Components**: ALB, target groups, security groups, listeners
- **Features**: HTTP to HTTPS redirect, SSL termination, health checks

### ECS Module (`./modules/ecs/`)
- **Purpose**: Container orchestration and execution
- **Components**: ECS cluster, service, task definition, IAM roles
- **Features**: Fargate deployment, EFS integration, ECS Exec, CloudWatch logs

## Resources Created

### Via ELB Submodule:
- Application Load Balancer (internet-facing)
- Target Group for ECS tasks
- Security Group for ALB (ports 80, 443)
- HTTP and HTTPS listeners with redirect

### Via ECS Submodule:
- ECS Cluster (Fargate)
- ECS Service with desired count of 1
- Task Definition with EFS volumes
- Security Group for ECS tasks
- IAM roles for task execution and EFS access
- CloudWatch Log Group

### External Dependencies:
- EFS Module (persistent storage)
- Network Module (VPC, subnets)
- ACM Module (SSL certificates)
- Database Module (RDS connectivity)

## Dependencies

- Requires `network` module for VPC and subnets
- Requires `db` module for database connectivity  
- Requires `acm` module for SSL certificate
- Uses `efs` module for persistent storage

## Security Features

- **Network Security**: Security groups with minimal required access
- **IAM Security**: Least privilege roles for tasks
- **Data Security**: EFS encryption in transit
- **SSL/TLS**: HTTPS termination at load balancer
- **Container Security**: ECS Exec for secure debugging

## Monitoring & Observability

- **Logs**: CloudWatch logs with configurable retention
- **Metrics**: ECS service and task metrics
- **Health Checks**: ALB health checks for availability
- **Debugging**: ECS Exec for container access

## High Availability

- **Multi-AZ**: Load balancer spans multiple availability zones
- **Auto-recovery**: ECS automatically replaces failed tasks
- **Health Monitoring**: Unhealthy tasks are automatically replaced
- **Persistent Storage**: EFS provides durable, shared storage

## Important Notes

- Application runs on Fargate with 512 CPU and 1024 MB memory
- ECS Exec is enabled for container debugging
- Health checks configured for path "/fake" expecting 404 response
- HTTPS redirect is automatic from HTTP
- Persistent data stored in EFS mounted at `/data`
- Service runs in public subnets with public IP for ALB access
- CloudWatch logs retained for 7 days by default

## Customization

The submodules can be customized by modifying their variables:
- Adjust CPU/memory allocation in ECS module
- Modify health check settings in ELB module  
- Change log retention in ECS module
- Customize security group rules as needed
