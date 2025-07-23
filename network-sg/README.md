# Network & Security Groups Module

This module creates the foundational VPC networking infrastructure and comprehensive security groups for the entire Forgejo Cloud application stack.

## 🏗️ Architecture

Creates a robust, secure network foundation with proper segmentation:

```
┌─────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)               │
├─────────────────────┬───────────────────────────────┤
│   Public Subnets    │        Private Subnets        │
│                     │                               │
│  ┌─────────────┐   │    ┌─────────────────────────┐ │
│  │     ALB     │   │    │      RDS Database       │ │
│  │   Jenkins   │   │    │      EFS Storage        │ │
│  │  NAT Gateway│   │    │                         │ │
│  └─────────────┘   │    └─────────────────────────┘ │
└─────────────────────┴───────────────────────────────┘
```

## 📦 Resources Created

### Networking Components
- **VPC**: 10.0.0.0/16 with DNS resolution enabled
- **Public Subnets**: For ALB, Jenkins, and NAT Gateway
- **Private Subnets**: For RDS, EFS, and secure resources
- **Internet Gateway**: For public internet access
- **NAT Gateway**: For private subnet outbound connectivity
- **Route Tables**: Proper routing for public and private traffic

### Security Groups
- **ALB Security Group**: HTTP/HTTPS traffic (ports 80, 443)
- **ECS Security Group**: Container communication and ALB access
- **RDS Security Group**: MySQL access from ECS (port 3306)
- **EFS Security Group**: NFS access from ECS (port 2049)
- **Jenkins Security Group**: SSH and HTTP access with IP restrictions

## 🚀 Usage

## 🚀 Usage

1. **Initialize Terraform:**
```bash
terraform init
```

2. **Review the plan:**
```bash
terraform plan
```

3. **Deploy infrastructure:**
```bash
terraform apply
```

## ⚙️ Configuration Variables

### Required Variables
- `aws_region` - AWS region for deployment (default: "us-east-1")
- `project_name` - Name prefix for resources (default: "forgejo")
- `environment` - Environment name (default: "prod")

### Networking Variables
- `vpc_cidr` - CIDR block for VPC (default: "10.0.0.0/16")
- `azs` - Availability zones (default: ["us-east-1a", "us-east-1b"])
- `public_subnets` - Public subnet CIDRs (default: ["10.0.1.0/24", "10.0.2.0/24"])
- `private_subnets` - Private subnet CIDRs (default: ["10.0.3.0/24", "10.0.4.0/24"])
- `enable_nat_gateway` - Enable NAT Gateway (default: true)

### Security Configuration
- `allowed_cidr_blocks` - CIDR blocks allowed for Jenkins access

## 📤 Outputs

### Network Outputs
- `vpc_id` - ID of the created VPC
- `public_subnets` - List of public subnet IDs
- `private_subnets` - List of private subnet IDs
- `internet_gateway_id` - Internet Gateway ID
- `nat_gateway_id` - NAT Gateway ID

### Security Group Outputs
- `alb_security_group_id` - Security group for Application Load Balancer
- `ecs_security_group_id` - Security group for ECS containers
- `rds_security_group_id` - Security group for RDS database
- `efs_security_group_id` - Security group for EFS file system
- `jenkins_security_group_id` - Security group for Jenkins EC2 instance

## 🔒 Security Groups Details

### ALB Security Group
```
Inbound:  HTTP (80) from 0.0.0.0/0
          HTTPS (443) from 0.0.0.0/0
Outbound: All traffic to ECS security group
```

### ECS Security Group
```
Inbound:  HTTP (3000) from ALB security group
          NFS (2049) to EFS security group
Outbound: All traffic to 0.0.0.0/0
```

### RDS Security Group
```
Inbound:  MySQL (3306) from ECS security group
Outbound: None
```

### EFS Security Group
```
Inbound:  NFS (2049) from ECS security group
Outbound: None
```

### Jenkins Security Group
```
Inbound:  SSH (22) from specified CIDR blocks
          HTTP (8080) from specified CIDR blocks
Outbound: All traffic to 0.0.0.0/0
```

## 🎯 Dependencies

- **None** - This is the foundation module that should be deployed first
- All other modules depend on the outputs from this module

## 💡 Important Notes

- **Deploy First**: This module creates the network foundation for all other modules
- **Cost Optimization**: Single NAT Gateway configuration (can be scaled to multiple AZs)
- **DNS Resolution**: Enabled for proper internal communication
- **Security**: Security groups follow least privilege principle
- **State**: Terraform state stored in S3: `network-sg/terraform.tfstate`
- DNS hostnames are enabled for proper service discovery
