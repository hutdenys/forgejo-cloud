# Forgejo Cloud Infrastructure

This repository contains Terraform infrastructure as code for deploying Forgejo (a lightweight Git service) on AWS using a microservices architecture with separate state management.

## Architecture Overview

The infrastructure is split into independent modules, each managing its own Terraform state:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Network   │    │     ACM     │    │     EFS     │
│   (VPC)     │    │ (SSL Cert)  │    │ (Storage)   │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                  ┌─────────────┐    ┌─────────────┐
                  │     App     │    │     DB      │
                  │   (ECS)     │    │   (RDS)     │
                  └─────────────┘    └─────────────┘
                           │                   
                  ┌─────────────┐    ┌─────────────┐
                  │  Route 53   │    │   Jenkins   │
                  │   (DNS)     │    │   (CI/CD)   │
                  └─────────────┘    └─────────────┘
```

## Modules

### 1. Network (`network/`)
- **Purpose**: VPC, subnets, gateways, and basic networking
- **Resources**: VPC, public/private subnets, IGW, NAT Gateway
- **Dependencies**: None (deploy first)

### 2. ACM (`acm/`)
- **Purpose**: SSL/TLS certificates for HTTPS
- **Resources**: ACM certificate with DNS validation
- **Dependencies**: None

### 3. Database (`db/`)
- **Purpose**: MySQL RDS instance for Forgejo data
- **Resources**: RDS instance, security groups, subnet groups
- **Dependencies**: Network module

### 4. EFS (`efs/`)
- **Purpose**: Persistent file storage for Forgejo repositories
- **Resources**: EFS file system, mount targets, access points
- **Dependencies**: Network module

### 5. Application (`app/`)
- **Purpose**: Main Forgejo application on ECS Fargate
- **Resources**: ECS cluster, ALB, security groups, IAM roles
- **Dependencies**: Network, Database, ACM, EFS modules

### 6. Route 53 (`route53/`)
- **Purpose**: DNS management for custom domains
- **Resources**: A/CNAME records, health checks, CloudWatch alarms
- **Dependencies**: Application module (ALB), optionally Jenkins module

### 7. Jenkins (`jenkins/`)
- **Purpose**: CI/CD pipeline server
- **Resources**: EC2 instance, EBS storage, security groups
- **Dependencies**: Network module

## Deployment Order

Deploy modules in the following order due to dependencies:

1. **Network** - Creates VPC and networking foundation
2. **ACM** - Creates SSL certificate (can be parallel with network)
3. **Database** - Creates RDS instance
4. **EFS** - Creates file storage (can be parallel with database)
5. **Application** - Deploys the main application
6. **Jenkins** - Deploys CI/CD server (optional, can be parallel with app)
7. **Route 53** - Creates DNS records (deploy after app and jenkins)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd forgejo-cloud
   ```

2. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

3. **Deploy infrastructure:**
   ```bash
   # Option 1: Use Makefile for automated deployment
   make quick-deploy
   
   # Option 2: Manual deployment in correct order
   # Deploy network first
   cd network/
   terraform init
   terraform apply
   
   # Deploy ACM certificate
   cd ../acm/
   terraform init
   terraform apply
   
   # Deploy database
   cd ../db/
   terraform init
   terraform apply
   
   # Deploy EFS
   cd ../efs/
   terraform init
   terraform apply
   
   # Deploy application
   cd ../app/
   terraform init
   terraform apply
   
   # Deploy Jenkins (optional)
   cd ../jenkins/
   terraform init
   terraform apply
   
   # Deploy Route 53 DNS
   cd ../route53/
   terraform init
   terraform apply
   ```

4. **Configure Route 53 (if using custom domain):**
   ```bash
   # Edit Route 53 configuration
   cd route53/
   vim terraform.tfvars
   # Set your domain_name and other DNS settings
   ```

## Configuration

Each module has its own `terraform.tfvars` file for configuration. Key settings:

- **Network**: VPC CIDR, subnet ranges, availability zones
- **ACM**: Domain name for SSL certificate
- **Database**: Instance class, credentials, database name
- **Application**: Forgejo Docker image version
- **Route 53**: Domain name, subdomains, health check settings
- **Jenkins**: Instance type, key pair, allowed IP ranges

## State Management

Each module maintains its own Terraform state in S3:
- `network/terraform.tfstate`
- `acm/terraform.tfstate`
- `db/terraform.tfstate`
- `efs/terraform.tfstate`
- `app/terraform.tfstate`
- `jenkins/terraform.tfstate`
- `route53/terraform.tfstate`

This separation allows for:
- Independent deployments
- Reduced blast radius
- Better team collaboration
- Easier maintenance

## Management Commands

The project includes a comprehensive Makefile for infrastructure management:

### Scaling Commands
- `make scale COUNT=N` - Scale Forgejo to N containers
- `make scale-up` - Increase container count by 1
- `make scale-down` - Decrease container count by 1

### Monitoring Commands
- `make status` - Show ECS service status
- `make logs` - Show recent application logs
- `make tasks` - List running ECS tasks

### Deployment Commands
- `make deploy-app` - Deploy/update Forgejo application
- `make deploy-jenkins` - Deploy/update Jenkins
- `make deploy-route53` - Deploy/update Route 53 DNS
- `make deploy-all` - Deploy all infrastructure modules
- `make quick-deploy` - Deploy all modules in correct order

### Infrastructure Commands
- `make init-all` - Initialize all Terraform modules
- `make plan-all` - Plan all Terraform modules
- `make destroy-all` - Destroy all infrastructure

### Utility Commands
- `make endpoints` - Show service endpoints and DNS names
- `make ssh-jenkins` - SSH to Jenkins instance
- `make check-dns` - Check DNS resolution for custom domains

- Database deployed in private subnets
- EFS encrypted at rest
- SSL/TLS termination at ALB
- Security groups with minimal required access
- IAM roles with least privilege
- ECS Exec enabled for debugging

## Monitoring and Maintenance

- ALB health checks configured
- ECS service auto-recovery
- Automated database backups
- CloudWatch logs integration
- ECS Exec for container access

## Cost Optimization

- Single NAT Gateway configuration
- t3.micro RDS instance (can be scaled)
- Fargate with minimal CPU/memory allocation
- EFS with standard storage class

## Troubleshooting

See individual module README files for specific troubleshooting guides.

## Contributing

1. Make changes in feature branches
2. Test in development environment
3. Update documentation
4. Submit pull request
