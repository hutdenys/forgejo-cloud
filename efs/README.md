# EFS Storage Module

This module creates encrypted Amazon Elastic File System (EFS) for persistent storage of Forgejo repositories, configurations, and data.

## 🗄️ Purpose

Provides persistent, scalable file storage for:
- **Git repositories**: All Forgejo repositories and Git data
- **Application data**: User uploads, avatars, attachments
- **Configuration**: Forgejo configuration and customizations
- **Logs**: Application logs (optional)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    EFS File System                     │
│                    (Encrypted)                         │
├─────────────────────┬───────────────────────────────────┤
│    Mount Target     │          Mount Target             │
│   (AZ us-east-1a)   │        (AZ us-east-1b)           │
└─────────┬───────────┴─────────────┬─────────────────────┘
          │                         │
          ▼                         ▼
    ┌─────────────┐           ┌─────────────┐
    │ ECS Task 1  │           │ ECS Task 2  │
    │  /data      │           │  /data      │
    └─────────────┘           └─────────────┘
```

## 🚀 Usage

### ⚠️ Important: Deployment Order

**EFS must be deployed AFTER the app module** because it requires the ECS security group:

```bash
# 1. Deploy app module first (creates ECS security group)
cd ../app
terraform apply

# 2. Then deploy EFS module
cd ../efs
terraform init
terraform plan
terraform apply
```

### Manual Deployment Steps

1. **Initialize Terraform:**
```bash
terraform init
```

2. **Verify app module is deployed:**
```bash
# Check that app module outputs ECS security group
cd ../app && terraform output ecs_security_group_id
cd ../efs
```

3. **Deploy EFS:**
```bash
terraform plan
terraform apply
```

## ⚙️ Configuration Variables

### Storage Configuration
```hcl
# Storage performance and throughput
performance_mode    = "generalPurpose"  # or "maxIO"
throughput_mode    = "provisioned"      # or "bursting"
provisioned_throughput_in_mibps = 100   # if throughput_mode = "provisioned"

# Lifecycle management
transition_to_ia = "AFTER_30_DAYS"      # Cost optimization
transition_to_primary_storage_class = "AFTER_1_ACCESS"
```

### Security Configuration
```hcl
# Encryption settings
creation_token = "forgejo-efs"
encrypted      = true                    # Always encrypted
kms_key_id     = null                   # Uses AWS managed key

# Access control
enable_backup_policy = true
```

### Example terraform.tfvars
```hcl
performance_mode = "generalPurpose"
throughput_mode  = "bursting"           # Cost-effective for most workloads
transition_to_ia = "AFTER_30_DAYS"      # Move to cheaper storage after 30 days
enable_backup_policy = true             # Enable automatic backups
```

## 📤 Outputs

### EFS Outputs
- `efs_file_system_id` - EFS file system ID (used by ECS tasks)
- `efs_file_system_arn` - EFS file system ARN
- `efs_dns_name` - EFS DNS name for mounting
- `efs_access_point_id` - Access point ID for ECS integration

### Security Outputs
- `efs_security_group_id` - Security group for EFS access
- `mount_target_ids` - List of mount target IDs

## 🔒 Security Configuration

### Network Security
- **Private Subnets Only**: EFS accessible only from private subnets
- **Security Group**: Restricted NFS access from ECS containers only
- **Encryption**: Data encrypted at rest and in transit

### Access Control Rules
```
EFS Security Group:
  Inbound:  NFS (2049) from ECS Security Group only
  Outbound: None (EFS doesn't initiate connections)

Mount Targets:
  - Created in each private subnet
  - Use EFS security group for access control
  - No public IP addresses
```

### Encryption
- **At Rest**: All data encrypted using AWS KMS
- **In Transit**: TLS encryption for NFS traffic
- **KMS Key**: AWS managed key (cost-effective) or customer managed key

## 🗃️ EFS Access Point

Access point provides application-specific entry point:

```hcl
# Access point configuration
resource "aws_efs_access_point" "forgejo" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 1000    # forgejo group
    uid = 1000    # forgejo user
  }

  root_directory {
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
    path = "/forgejo"
  }
}
```

## 🎯 Dependencies

### Required Modules
1. **network-sg** - Private subnets and security groups
2. **app** - ECS security group (critical dependency)

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

# App module (for ECS security group)
data "terraform_remote_state" "app" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "app/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## 📊 Performance & Monitoring

### Performance Modes

1. **General Purpose** (Default):
   - Up to 7,000 file operations per second
   - Lower latency per operation
   - Suitable for most workloads

2. **Max I/O**:
   - Higher levels of aggregate throughput
   - Higher latency per operation
   - For applications needing high performance

### Throughput Modes

1. **Bursting** (Cost-effective):
   - Baseline performance scales with file system size
   - Can burst to higher levels
   - Good for variable workloads

2. **Provisioned**:
   - Consistent high throughput
   - Independent of storage size
   - Higher cost but predictable performance

### CloudWatch Metrics
```bash
# Monitor EFS performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name TotalIOBytes \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## 💰 Cost Optimization

### Storage Classes
- **Standard**: Frequently accessed data
- **Infrequent Access (IA)**: Data accessed less than daily (50% cost reduction)
- **Archive**: Long-term storage (80% cost reduction)

### Lifecycle Policies
```hcl
# Automatic cost optimization
lifecycle_policy {
  transition_to_ia                    = "AFTER_30_DAYS"
  transition_to_primary_storage_class = "AFTER_1_ACCESS"
}
```

### Cost Monitoring
```bash
# Check storage utilization
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --query 'FileSystems[0].SizeInBytes'
```

## 🔍 Troubleshooting

### Common Issues

1. **EFS Mount Fails**:
```bash
# Check security group allows NFS traffic
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[0].IpPermissions'

# Test mount from ECS task
aws ecs execute-command \
  --cluster forgejo-cluster \
  --task <task-id> \
  --container forgejo \
  --command "mount -t efs fs-xxxxx:/ /mnt/test"
```

2. **Permission Denied**:
```bash
# Check access point configuration
aws efs describe-access-points \
  --file-system-id fs-xxxxx

# Verify POSIX permissions
ls -la /data  # Inside container
```

3. **Performance Issues**:
```bash
# Check throughput mode
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --query 'FileSystems[0].ThroughputMode'

# Monitor CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name PercentIOLimit
```

### Debug Commands

```bash
# EFS file system details
aws efs describe-file-systems

# Mount target status
aws efs describe-mount-targets \
  --file-system-id fs-xxxxx

# Access point details
aws efs describe-access-points \
  --file-system-id fs-xxxxx
```

## 🔧 Maintenance

### Backup Management
```bash
# Manual backup
aws efs put-backup-policy \
  --file-system-id fs-xxxxx \
  --backup-policy Status=ENABLED

# List backup recovery points
aws backup list-recovery-points-by-resource \
  --resource-arn arn:aws:elasticfilesystem:us-east-1:account:file-system/fs-xxxxx
```

### Performance Tuning
```bash
# Update throughput mode
aws efs modify-file-system \
  --file-system-id fs-xxxxx \
  --throughput-mode provisioned \
  --provisioned-throughput-in-mibps 500
```

## 💡 Important Notes

- **Deployment Order**: Must deploy after app module (requires ECS security group)
- **Encryption**: Always enabled for security compliance
- **Multi-AZ**: Mount targets created in all private subnets for availability
- **Persistent Data**: All Forgejo data persists across container restarts/updates
- **Scalability**: EFS automatically scales with usage
- **State Storage**: Terraform state in S3: `efs/terraform.tfstate`

## 🔄 Integration with ECS

### Task Definition Mount
```json
{
  "mountPoints": [
    {
      "sourceVolume": "forgejo-data",
      "containerPath": "/data",
      "readOnly": false
    }
  ],
  "volumes": [
    {
      "name": "forgejo-data",
      "efsVolumeConfiguration": {
        "fileSystemId": "${efs_file_system_id}",
        "accessPointId": "${efs_access_point_id}",
        "transitEncryption": "ENABLED"
      }
    }
  ]
}
```

This ensures all Forgejo data is stored persistently and shared across multiple container instances.

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
