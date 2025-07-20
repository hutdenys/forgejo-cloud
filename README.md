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

## Deployment Order

Deploy modules in the following order due to dependencies:

1. **Network** - Creates VPC and networking foundation
2. **ACM** - Creates SSL certificate (can be parallel with network)
3. **Database** - Creates RDS instance
4. **EFS** - Creates file storage (can be parallel with database)
5. **Application** - Deploys the main application

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
   ```

## Configuration

Each module has its own `terraform.tfvars` file for configuration. Key settings:

- **Network**: VPC CIDR, subnet ranges, availability zones
- **ACM**: Domain name for SSL certificate
- **Database**: Instance class, credentials, database name
- **Application**: Forgejo Docker image version

## State Management

Each module maintains its own Terraform state in S3:
- `network/terraform.tfstate`
- `acm/terraform.tfstate`
- `db/terraform.tfstate`
- `efs/terraform.tfstate`
- `app/terraform.tfstate`

This separation allows for:
- Independent deployments
- Reduced blast radius
- Better team collaboration
- Easier maintenance

## Security Considerations

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
