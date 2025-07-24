# Forgejo Cloud Infrastructure

**Complete solution for deploying Forgejo (Git service) on AWS with microservices architecture and full automation**

This repository contains Terraform Infrastructure as Code for deploying a scalable Forgejo Git service on AWS using ECS Fargate, RDS, EFS, and a complete CI/CD toolchain.

## 🏗️ Architecture Overview

The infrastructure is split into independent modules with separate state management for better modularity and scalability:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Forgejo Cloud Infrastructure                  │
├─────────────┬─────────────┬─────────────┬─────────────────────────┤
│ Network-SG  │     ACM     │     EFS     │        Route 53         │
│ VPC & Sec   │ SSL/TLS     │  Storage    │      DNS Management     │
│ Groups      │ Certificate │ Encrypted   │    Custom Domains       │
└─────┬───────┴─────┬───────┴─────┬───────┴──────────┬──────────────┘
      │             │             │                  │
      └─────────────┼─────────────┼──────────────────┘
                    │             │
         ┌──────────┴──────┬──────┴──────┐
         │                 │             │
    ┌────▼────┐      ┌─────▼─────┐  ┌────▼────┐
    │   App   │      │    DB     │  │ Jenkins │
    │  (ECS)  │◄────►│  (RDS)    │  │ (CI/CD) │
    │ Fargate │      │  MySQL    │  │  EC2    │
    └─────────┘      └───────────┘  └─────────┘
```

## 📦 Modules

## 📦 Modules

### 1. **Network & Security Groups** (`network-sg/`)
- **Purpose**: VPC, subnets, gateways, and comprehensive security groups
- **Resources**: VPC, public/private subnets, IGW, NAT Gateway, Security Groups for all services
- **Dependencies**: None (deploy first)

### 2. **ACM Certificate** (`acm/`)
- **Purpose**: SSL/TLS certificates for HTTPS encryption
- **Resources**: ACM certificate with DNS validation for `forgejo.pp.ua`
- **Dependencies**: None (can deploy in parallel with network)

### 3. **Persistent EBS for Jenkins** (`ebs-jenkins/`)
- **Purpose**: Persistent EBS volume for Jenkins home directory that survives terraform destroy
- **Resources**: Encrypted GP3 EBS volume with lifecycle protection
- **Dependencies**: None (but must be in same AZ as Jenkins)
- **Features**: `prevent_destroy` lifecycle rule, independent state management

### 4. **Database** (`db/`)
- **Purpose**: MySQL RDS instance for Forgejo data persistence
- **Resources**: RDS instance (db.t3.micro), subnet groups, security groups
- **Dependencies**: Network module

### 5. **EFS Storage** (`efs/`)
- **Purpose**: Persistent file storage for Forgejo repositories
- **Resources**: EFS file system (encrypted), mount targets, access points
- **Dependencies**: Network and App modules (requires ECS security group)

### 5. **Application** (`app/`)
- **Purpose**: Main Forgejo application on ECS Fargate with load balancing
- **Resources**: ECS cluster, ALB with SSL, security groups, IAM roles
- **Submodules**: ELB (Application Load Balancer), ECS (Elastic Container Service)
- **Dependencies**: Network, Database, ACM modules

### 6. **Route 53 DNS** (`route53/`)
- **Purpose**: DNS management for custom domains and subdomains
- **Resources**: A/CNAME records, health checks, CloudWatch monitoring
- **Domains**: `forgejo.pp.ua`, `jenkins.forgejo.pp.ua`
- **Dependencies**: Application module (ALB), optionally Jenkins module

### 7. **Jenkins CI/CD** (`jenkins/`)
- **Purpose**: Continuous Integration/Continuous Deployment server
- **Resources**: EC2 instance (t3.small), EBS storage (50GB), security groups
- **Dependencies**: Network module

## 🚀 Deployment Order

## 🚀 Deployment Order

Deploy modules in the following order due to dependencies:

1. **network-sg** - Creates VPC and networking foundation with security groups
2. **acm** - Creates SSL certificate (can deploy in parallel with network)
3. **db** - Creates RDS MySQL instance
4. **app** - Deploys the main Forgejo application (creates ECS security group needed by EFS)
5. **efs** - Creates file storage (requires ECS security group from app module)
6. **jenkins** - Deploys CI/CD server (optional, can deploy in parallel with app)
7. **route53** - Creates DNS records (deploy after app and jenkins are ready)

## ⚡ Quick Start

### Automated Deployment (Recommended)

```bash
# Clone repository
git clone <repository-url>
cd forgejo-cloud

# Configure AWS credentials
aws configure

# Quick deployment of entire infrastructure
make quick-deploy

# Check deployment status and endpoints
make status
make endpoints
```

### Manual Step-by-Step Deployment

```bash
# 1. Network and security groups
cd network-sg && terraform init && terraform apply && cd ..

# 2. SSL certificate
cd acm && terraform init && terraform apply && cd ..

# 3. Database
cd db && terraform init && terraform apply && cd ..

# 4. Application (creates ECS security group)
cd app && terraform init && terraform apply && cd ..

# 5. File storage (requires ECS security group)
cd efs && terraform init && terraform apply && cd ..

# 6. Jenkins (optional)
cd jenkins && terraform init && terraform apply && cd ..

# 7. DNS records
cd route53 && terraform init && terraform apply && cd ..
```

## ⚙️ Configuration

Each module has its own `terraform.tfvars` file for customization:

- **network-sg**: VPC CIDR (10.0.0.0/16), availability zones, subnet ranges
- **acm**: Domain name for SSL certificate (`forgejo.pp.ua`)
- **db**: MySQL instance class (db.t3.micro), credentials, database name
- **app**: Forgejo Docker image version, container resources
- **efs**: Storage class, encryption settings
- **jenkins**: EC2 instance type (t3.small), key pair, allowed IP ranges
- **route53**: Domain names, DNS record types, health check settings

## 🗂️ State Management

Each module maintains its own Terraform state in S3 for better isolation:

```
S3 Bucket: my-tf-state-bucket535845769543
├── network-sg/terraform.tfstate
├── acm/terraform.tfstate
├── db/terraform.tfstate
├── efs/terraform.tfstate
├── app/terraform.tfstate
├── jenkins/terraform.tfstate
└── route53/terraform.tfstate
```

**Benefits of separate states:**
- Independent deployments and rollbacks
- Reduced blast radius for changes
- Better team collaboration
- Easier maintenance and troubleshooting

## 🛠️ Management Commands

The project includes a comprehensive Makefile for infrastructure management:

### Scaling Commands
- `make scale COUNT=N` - Scale Forgejo service to N containers
- `make scale-up` - Increase container count by 1
- `make scale-down` - Decrease container count by 1

### Monitoring Commands
- `make status` - Show ECS service status and health
- `make logs` - Show recent application logs (last 1 hour)
- `make tasks` - List running ECS tasks with details

### Deployment Commands
- `make deploy-app` - Deploy/update Forgejo application
- `make deploy-jenkins` - Deploy/update Jenkins server
- `make deploy-route53` - Deploy/update Route 53 DNS records
- `make deploy-all` - Deploy all infrastructure modules
- `make quick-deploy` - Deploy all modules in correct dependency order

### Infrastructure Commands
- `make init-all` - Initialize all Terraform modules
- `make plan-all` - Plan all Terraform modules
- `make destroy-all` - Destroy all infrastructure (with confirmation)

### Utility Commands
- `make endpoints` - Show service endpoints and URLs
- `make ssh-jenkins` - SSH into Jenkins EC2 instance
- `make check-dns` - Check DNS resolution for custom domains

## 🔒 Security Features

## 🔒 Security Features

- **Network Isolation**: Database and EFS deployed in private subnets
- **Encryption**: EFS encrypted at rest, SSL/TLS termination at ALB
- **Access Control**: Security groups with minimal required access
- **IAM**: Roles with least privilege principle
- **Monitoring**: ECS Exec enabled for secure container debugging
- **SSH Access**: Jenkins accessible only from specified IP ranges

## 📊 Monitoring and Maintenance

- **Health Checks**: ALB health checks for application availability
- **Auto Recovery**: ECS service auto-recovery on failures
- **Backups**: Automated RDS database backups with point-in-time recovery
- **Logging**: CloudWatch logs integration for centralized log management
- **Debugging**: ECS Exec for secure container access without SSH

## 💰 Cost Optimization

- **Networking**: Single NAT Gateway configuration (can be scaled to multiple AZs)
- **Database**: t3.micro RDS instance (easily scalable)
- **Compute**: Fargate with minimal CPU/memory allocation (0.25 vCPU, 0.5GB RAM)
- **Storage**: EFS with standard storage class
- **Jenkins**: t3.small EC2 instance with 50GB EBS storage

## 🌐 Access URLs

After successful deployment:

- **Forgejo Git Service**: `https://forgejo.pp.ua`
- **Jenkins CI/CD**: `http://jenkins.forgejo.pp.ua:8080`
- **Direct ALB Access**: Available via `make endpoints` command

## 🔧 Troubleshooting

### Common Issues

1. **EFS Mount Issues**: Ensure app module is deployed before EFS (EFS needs ECS security group)
2. **DNS Resolution**: Use `make check-dns` to verify Route 53 records
3. **SSL Certificate**: Verify ACM certificate validation in AWS console
4. **Jenkins Access**: Check security group allows your IP address

### Debug Commands

```bash
# Check ECS service status
make status

# View application logs
make logs

# List running tasks
make tasks

# Check all endpoints
make endpoints

# Test DNS resolution
make check-dns

# SSH into Jenkins
make ssh-jenkins
```

See individual module README files for specific troubleshooting guides.

## 🤝 Contributing

1. Create feature branches for changes
2. Test in development environment first
3. Update relevant documentation
4. Submit pull request with detailed description

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
