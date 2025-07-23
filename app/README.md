# Application Module (ECS Fargate)

This module deploys the Forgejo Git service on AWS ECS Fargate with Application Load Balancer, SSL termination, and integrated monitoring. The module is organized into submodules for better maintainability and reusability.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Module                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │     ELB     │  │     ECS     │  │         EFS             │ │
│  │   (ALB +    │◄─┤   (Fargate  │◄─┤     (External)         │ │
│  │  SSL/TLS)   │  │   + Tasks)  │  │  Persistent Storage     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

External Dependencies:
├── Network (VPC, Subnets, Security Groups)
├── Database (RDS MySQL)
├── ACM (SSL Certificate)
└── EFS (File Storage) - deployed after this module
```

## 🚀 Usage

1. **Ensure dependencies are deployed:**
```bash
# Verify network, ACM, and database modules
cd ../network-sg && terraform output
cd ../acm && terraform output
cd ../db && terraform output
```

2. **Deploy application:**
```bash
terraform init
terraform plan
terraform apply
```

3. **Verify deployment:**
```bash
# Check service status
make status

# Get application endpoint
terraform output alb_dns_name
```

## ⚙️ Configuration Variables

### Required Variables
- `forgejo_image` - Docker image for Forgejo (default: "codeberg.org/forgejo/forgejo:1.21")

### Optional Variables
```hcl
cluster_name         = "forgejo-cluster"
service_name         = "forgejo"
container_port       = 3000
desired_count        = 1
cpu                  = 256    # 0.25 vCPU
memory              = 512    # 0.5 GB
enable_execute_command = true  # For debugging
```

### Example terraform.tfvars
```hcl
forgejo_image = "codeberg.org/forgejo/forgejo:1.21-rootless"
desired_count = 2
cpu          = 512  # 0.5 vCPU
memory       = 1024 # 1 GB
```

## 📤 Outputs

### Application Outputs
- `alb_dns_name` - DNS name of the Application Load Balancer
- `alb_zone_id` - Zone ID of the ALB (for Route 53)
- `alb_hosted_zone_id` - Hosted zone ID for DNS records

### ECS Outputs
- `ecs_cluster_name` - Name of the ECS cluster
- `ecs_service_name` - Name of the ECS service
- `ecs_security_group_id` - Security group ID for ECS tasks (needed by EFS)
- `task_definition_arn` - ARN of the task definition

### Load Balancer Outputs
- `target_group_arn` - ARN of the target group
- `alb_security_group_id` - Security group ID for ALB

## 🧩 Submodules

### ELB Module (`./modules/elb/`)

**Purpose**: Application Load Balancer with SSL termination and HTTP→HTTPS redirect

**Components**:
- Application Load Balancer (internet-facing)
- Target Groups with health checks
- HTTPS Listener (port 443) with SSL certificate
- HTTP Listener (port 80) with redirect to HTTPS
- Security Groups for ALB traffic

**Health Checks**:
```hcl
health_check = {
  enabled             = true
  healthy_threshold   = 2
  unhealthy_threshold = 2
  timeout             = 5
  interval            = 30
  path                = "/api/healthz"
  matcher             = "200"
  port                = "traffic-port"
  protocol            = "HTTP"
}
```

### ECS Module (`./modules/ecs/`)

**Purpose**: ECS Fargate cluster with containerized Forgejo application

**Components**:
- ECS Cluster with container insights
- Task Definition with Forgejo container
- ECS Service with auto-scaling capabilities
- IAM Roles and Policies
- Security Groups for container communication
- EFS mount configuration

**Container Configuration**:
```json
{
  "name": "forgejo",
  "image": "codeberg.org/forgejo/forgejo:1.21",
  "portMappings": [{"containerPort": 3000}],
  "environment": [
    {"name": "FORGEJO__database__DB_TYPE", "value": "mysql"},
    {"name": "FORGEJO__database__HOST", "value": "${db_endpoint}"},
    {"name": "FORGEJO__database__NAME", "value": "${db_name}"}
  ],
  "mountPoints": [
    {
      "sourceVolume": "forgejo-data",
      "containerPath": "/data"
    }
  ]
}
```

## 🔒 Security Features

### Network Security
- **ALB**: Public subnets with internet gateway access
- **ECS**: Private subnets with NAT gateway for outbound only
- **Database**: Private subnets, ECS access only

### IAM Permissions
- **Task Execution Role**: ECR, CloudWatch logs access
- **Task Role**: EFS mount, parameter store access
- **Least Privilege**: Minimal required permissions only

### Security Groups
```
ALB Security Group:
  Inbound:  80, 443 from 0.0.0.0/0
  Outbound: 3000 to ECS Security Group

ECS Security Group:
  Inbound:  3000 from ALB Security Group
  Outbound: 443 to 0.0.0.0/0 (for Git operations)
           3306 to RDS Security Group
           2049 to EFS Security Group
```

## 📊 Monitoring & Logging

### CloudWatch Integration
- **Container Insights**: Cluster and service metrics
- **Application Logs**: Centralized log group `/ecs/forgejo`
- **ALB Logs**: Access logs stored in S3 (optional)

### Health Monitoring
- **ALB Health Checks**: Application endpoint monitoring
- **ECS Service**: Auto-recovery on task failures
- **Target Group**: Automatic instance replacement

### Key Metrics to Monitor
```bash
# ECS Service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=forgejo Name=ClusterName,Value=forgejo-cluster

# ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/forgejo-alb/xxx
```

## 🎯 Dependencies

### Required Modules (Deploy First)
1. **network-sg** - VPC, subnets, security groups
2. **db** - RDS MySQL database
3. **acm** - SSL certificate

### Remote State Dependencies
```hcl
# Network infrastructure
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "network-sg/terraform.tfstate"
    region = "us-east-1"
  }
}

# Database configuration
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "db/terraform.tfstate"
    region = "us-east-1"
  }
}

# SSL certificate
data "terraform_remote_state" "acm" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "acm/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## 🔧 Scaling & Performance

### Horizontal Scaling
```bash
# Scale using Makefile
make scale COUNT=3        # Scale to 3 containers
make scale-up            # Add 1 container
make scale-down          # Remove 1 container

# Scale using AWS CLI
aws ecs update-service \
  --cluster forgejo-cluster \
  --service forgejo \
  --desired-count 3
```

### Vertical Scaling
```hcl
# Update terraform.tfvars
cpu    = 512   # 0.5 vCPU
memory = 1024  # 1 GB

# Apply changes
terraform plan
terraform apply
```

### Auto Scaling (Optional)
```hcl
# Enable auto scaling
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

## 🔍 Troubleshooting

### Common Issues

1. **Service Won't Start**:
```bash
# Check service events
aws ecs describe-services \
  --cluster forgejo-cluster \
  --services forgejo \
  --query 'services[0].events'

# Check task definition
aws ecs describe-task-definition \
  --task-definition forgejo
```

2. **Health Check Failures**:
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check application logs
make logs
```

3. **Database Connection Issues**:
```bash
# Execute into running container
aws ecs execute-command \
  --cluster forgejo-cluster \
  --task <task-id> \
  --container forgejo \
  --interactive \
  --command "/bin/sh"
```

### Debug Commands
```bash
# Application status
make status

# Recent logs
make logs

# Running tasks
make tasks

# Service endpoints
make endpoints
```

## 💡 Important Notes

- **EFS Integration**: This module creates the ECS security group needed by EFS module
- **SSL Certificate**: Requires valid ACM certificate for HTTPS
- **Database**: Application automatically configures MySQL connection
- **Persistent Data**: EFS mount ensures data persistence across deployments
- **State Storage**: Terraform state in S3: `app/terraform.tfstate`

## 🔄 Updates & Maintenance

### Application Updates
```bash
# Update Forgejo version
# Edit terraform.tfvars
forgejo_image = "codeberg.org/forgejo/forgejo:1.22"

# Deploy update
terraform apply

# Monitor deployment
make status
make logs
```

### Rolling Updates
- ECS automatically performs rolling updates
- Zero-downtime deployments with multiple instances
- Health checks prevent traffic to unhealthy instances
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
