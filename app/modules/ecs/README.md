# ECS (Elastic Container Service) Module

This module creates an ECS Fargate cluster, task definition, service, and all associated IAM roles and security groups for running the Forgejo application.

## Usage

This module is designed to be used as a submodule within the app module:

```terraform
module "ecs" {
  source = "./modules/ecs"

  name_prefix           = "forgejo"
  vpc_id                = var.vpc_id
  subnets               = var.public_subnets
  alb_security_group_id = module.elb.alb_security_group_id
  target_group_arn      = module.elb.target_group_arn
  container_image       = var.forgejo_image
  efs_file_system_id    = var.efs_file_system_id
  efs_access_point_id   = var.efs_access_point_id
}
```

## Variables

### Required
- `vpc_id`: VPC ID where ECS will be created
- `subnets`: List of subnet IDs for ECS service
- `alb_security_group_id`: Security group ID of the ALB
- `target_group_arn`: ARN of the target group
- `container_image`: Docker image for the container
- `efs_file_system_id`: EFS file system ID
- `efs_access_point_id`: EFS access point ID

### Optional
- `name_prefix`: Name prefix for resources (default: "forgejo")
- `container_name`: Name of the container (default: "forgejo")
- `container_port`: Port on which the container listens (default: 3000)
- `cpu`: CPU units for the task (default: "512")
- `memory`: Memory for the task (default: "1024")
- `desired_count`: Desired number of tasks (default: 1)
- `enable_execute_command`: Enable ECS Exec for debugging (default: true)
- `assign_public_ip`: Assign public IP to tasks (default: true)
- `mount_path`: Container mount path for EFS (default: "/data")
- `aws_region`: AWS region (default: "us-east-1")
- `log_retention_days`: CloudWatch log retention in days (default: 7)

## Outputs

- `ecs_cluster_name`: Name of the ECS cluster
- `ecs_cluster_id`: ID of the ECS cluster
- `ecs_service_name`: Name of the ECS service
- `ecs_service_id`: ID of the ECS service
- `ecs_security_group_id`: Security group ID of the ECS tasks
- `task_definition_arn`: ARN of the task definition
- `task_execution_role_arn`: ARN of the task execution role
- `task_role_arn`: ARN of the task role
- `log_group_name`: Name of the CloudWatch log group

## Resources Created

### Core ECS Resources
- **ECS Cluster**: Fargate cluster for running containers
- **Task Definition**: Container specification with EFS volumes
- **ECS Service**: Manages desired state of running tasks
- **Security Group**: Controls network access to containers

### IAM Resources
- **Task Execution Role**: Allows ECS to pull images and write logs
- **Task Role**: Allows containers to access AWS services (EFS)
- **Custom Policies**: ECS Exec permissions and EFS access

### Monitoring
- **CloudWatch Log Group**: Centralized logging for containers

## Features

### Container Configuration
- **Fargate Launch Type**: Serverless container execution
- **EFS Integration**: Persistent storage mounted at `/data`
- **Auto-scaling Ready**: Can be extended with auto-scaling policies
- **Health Checks**: Integrated with ALB health checks

### Security
- **Least Privilege**: IAM roles with minimal required permissions
- **Network Isolation**: Security groups with controlled access
- **Encrypted Storage**: EFS volumes with encryption in transit

### Monitoring & Debugging
- **CloudWatch Logs**: Automatic log collection and retention
- **ECS Exec**: SSH-like access to running containers for debugging
- **CloudWatch Integration**: Metrics and monitoring

### High Availability
- **Multi-AZ Deployment**: Tasks can run across multiple AZs
- **Auto-recovery**: ECS automatically replaces failed tasks
- **Load Balancer Integration**: Traffic distributed across healthy tasks

## Important Notes

- Tasks run in public subnets with public IPs for ALB access
- ECS Exec is enabled for debugging purposes
- EFS volumes are encrypted in transit
- CloudWatch logs have configurable retention
- Task execution role has permissions for image pulling and logging
- Task role has specific EFS access permissions only
