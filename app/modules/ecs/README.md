# ECS (Elastic Container Service) Module

This submodule creates a complete ECS Fargate infrastructure for running the Forgejo application with auto-scaling, service discovery, and integrated monitoring.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                 ECS Cluster                         │
│              (forgejo-cluster)                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐  ┌─────────────────────────┐   │
│  │   ECS Service   │  │    Task Definition      │   │
│  │                 │  │                         │   │
│  │ • Auto Scaling  │  │ • Forgejo Container     │   │
│  │ • Health Checks │  │ • Resource Limits       │   │
│  │ • Load Balancing│  │ • Environment Variables │   │
│  └─────────────────┘  │ • EFS Volume Mount      │   │
│                       │ • CloudWatch Logs       │   │
│                       └─────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │              Running Tasks                      │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐        │ │
│  │  │ Task 1  │  │ Task 2  │  │ Task N  │        │ │
│  │  │Private  │  │Private  │  │Private  │        │ │
│  │  │Subnet   │  │Subnet   │  │Subnet   │        │ │
│  │  └─────────┘  └─────────┘  └─────────┘        │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## 🎯 Features

- **Fargate Platform**: Serverless container management
- **Auto Scaling**: Horizontal scaling based on demand
- **Health Monitoring**: Integrated with ALB health checks
- **Service Discovery**: Internal DNS-based service discovery
- **Logging**: CloudWatch logs integration
- **Security**: IAM roles with least privilege
- **Persistent Storage**: EFS volume mounting
- **Debugging**: ECS Exec for container access

## 🚀 Usage

This module is designed as a submodule within the app module:

```hcl
module "ecs" {
  source = "./modules/ecs"

  # Required variables
  name_prefix           = "forgejo"
  vpc_id                = var.vpc_id
  subnets               = var.private_subnets
  alb_security_group_id = module.elb.alb_security_group_id
  target_group_arn      = module.elb.target_group_arn
  
  # Application configuration
  container_image       = var.forgejo_image
  efs_file_system_id    = var.efs_file_system_id
  efs_access_point_id   = var.efs_access_point_id
  
  # Database configuration
  db_endpoint = var.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}
```

## ⚙️ Variables

### Required Variables
```hcl
# Infrastructure
name_prefix           = "forgejo"
vpc_id                = "vpc-xxxxx"
subnets               = ["subnet-xxxxx", "subnet-yyyyy"]
alb_security_group_id = "sg-xxxxx"
target_group_arn      = "arn:aws:elasticloadbalancing:..."

# Application
container_image = "codeberg.org/forgejo/forgejo:1.21"

# Storage
efs_file_system_id  = "fs-xxxxx"
efs_access_point_id = "fsap-xxxxx"

# Database
db_endpoint = "forgejo-db.xxxxx.us-east-1.rds.amazonaws.com"
db_name     = "forgejo"
db_username = "forgejo"
db_password = "secure-password"  # Sensitive
```

### Optional Variables
```hcl
# ECS Configuration
cluster_name           = "forgejo-cluster"
service_name           = "forgejo"
desired_count          = 1
platform_version       = "LATEST"

# Container Resources
cpu                    = 256      # 0.25 vCPU
memory                 = 512      # 0.5 GB
container_port         = 3000

# Features
enable_execute_command = true     # For debugging
enable_container_insights = true  # Enhanced monitoring

# Auto Scaling
enable_auto_scaling    = false
min_capacity          = 1
max_capacity          = 5
target_cpu_utilization = 70

# Logging
log_retention_in_days = 30

# Tags
tags = {
  Environment = "prod"
  Project     = "forgejo"
}
```

## 📤 Outputs

### ECS Information
- `ecs_cluster_name` - Name of the ECS cluster
- `ecs_cluster_arn` - ARN of the ECS cluster
- `ecs_service_name` - Name of the ECS service
- `ecs_service_arn` - ARN of the ECS service

### Task Definition
- `task_definition_arn` - ARN of the task definition
- `task_definition_family` - Family name of the task definition
- `task_definition_revision` - Current revision number

### Security
- `ecs_security_group_id` - Security group ID for ECS tasks (used by EFS)
- `task_execution_role_arn` - ARN of the task execution role
- `task_role_arn` - ARN of the task role

## 🗂️ Resources Created

### ECS Cluster
```hcl
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.ecs.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
}
```

### Task Definition
```hcl
resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn           = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = var.container_image
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "FORGEJO__database__DB_TYPE"
          value = "mysql"
        },
        {
          name  = "FORGEJO__database__HOST"
          value = "${var.db_endpoint}:3306"
        },
        {
          name  = "FORGEJO__database__NAME"
          value = var.db_name
        },
        {
          name  = "FORGEJO__database__USER"
          value = var.db_username
        },
        {
          name  = "FORGEJO__database__PASSWD"
          value = var.db_password
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "forgejo-data"
          containerPath = "/data"
          readOnly      = false
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.container_port}/api/healthz || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])
  
  volume {
    name = "forgejo-data"
    
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      access_point_id    = var.efs_access_point_id
      transit_encryption = "ENABLED"
    }
  }
}
```

### ECS Service
```hcl
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  platform_version = var.platform_version

  network_configuration {
    subnets          = var.subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 50
  }

  enable_execute_command = var.enable_execute_command

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy_attachment.task
  ]
}
```

### Security Group
```hcl
resource "aws_security_group" "ecs" {
  name_prefix = "${var.name_prefix}-ecs-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "MySQL to RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "NFS to EFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
}
```

## 🔒 IAM Roles & Policies

### Task Execution Role
```hcl
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Managed policies
resource "aws_iam_role_policy_attachment" "execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.execution.name
}
```

### Task Role
```hcl
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Custom policy for EFS access
resource "aws_iam_role_policy" "task_efs" {
  name = "${var.name_prefix}-ecs-efs-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = var.efs_file_system_id
      }
    ]
  })
}
```

## 📊 Monitoring & Logging

### CloudWatch Logs
```hcl
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/exec/${var.service_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}
```

### Container Insights
```hcl
# Cluster-level metrics
setting {
  name  = "containerInsights"
  value = var.enable_container_insights ? "enabled" : "disabled"
}
```

### Key Metrics to Monitor
- **CPU Utilization**: Container and cluster level
- **Memory Utilization**: Container and cluster level
- **Task Count**: Running, pending, stopped tasks
- **Service Events**: Deployment and scaling events

## 🔧 Auto Scaling (Optional)

### Application Auto Scaling
```hcl
resource "aws_appautoscaling_target" "ecs" {
  count              = var.enable_auto_scaling ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}
```

## 🔍 Troubleshooting

### Common Issues

1. **Service Won't Start**:
```bash
# Check service events
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].events'

# Check task definition
aws ecs describe-task-definition \
  --task-definition $(terraform output -raw task_definition_family)
```

2. **Container Health Check Failures**:
```bash
# Check container logs
aws logs tail /ecs/forgejo --follow

# Execute into container
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task <task-id> \
  --container forgejo \
  --interactive \
  --command "/bin/sh"
```

3. **EFS Mount Issues**:
```bash
# Check EFS security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw ecs_security_group_id)

# Test EFS connectivity from container
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task <task-id> \
  --container forgejo \
  --command "ls -la /data"
```

### Debug Commands

```bash
# List running tasks
aws ecs list-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service-name $(terraform output -raw ecs_service_name)

# Describe specific task
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks <task-id>

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

## 💰 Cost Optimization

### Fargate Pricing
- **vCPU**: $0.04048 per vCPU per hour
- **Memory**: $0.004445 per GB per hour
- **Example**: 0.25 vCPU + 0.5GB = ~$15/month

### Optimization Tips
```hcl
# Right-size containers
cpu    = 256   # Start small
memory = 512   # Increase if needed

# Use Spot capacity (if suitable)
capacity_providers = ["FARGATE_SPOT"]

# Optimize log retention
log_retention_in_days = 7  # Reduce for cost savings
```

## 💡 Important Notes

- **Private Subnets**: ECS tasks run in private subnets for security
- **EFS Integration**: Requires proper security group configuration
- **Health Checks**: Both container and ALB health checks configured
- **Logging**: All logs centralized in CloudWatch
- **Security**: Least privilege IAM roles and security groups
- **Scaling**: Supports both manual and automatic scaling
- **Debugging**: ECS Exec enabled for troubleshooting
- **Database**: Environment variables configure MySQL connection

## 🔄 Deployment Best Practices

### Blue/Green Deployments
```hcl
deployment_configuration {
  maximum_percent         = 200
  minimum_healthy_percent = 100
}
```

### Rolling Updates
```hcl
deployment_configuration {
  maximum_percent         = 150
  minimum_healthy_percent = 50
}
```

### Zero-Downtime Deployments
- ALB health checks prevent traffic to unhealthy containers
- Rolling deployment strategy ensures availability
- EFS provides persistent data across deployments
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
