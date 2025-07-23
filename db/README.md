# Database Module (RDS MySQL)

This module creates a managed MySQL database instance using Amazon RDS for persistent Forgejo data storage.

## 🗄️ Architecture

- **Engine**: MySQL 8.0 (latest compatible version)
- **Instance**: db.t3.micro (1 vCPU, 1GB RAM) - cost-optimized
- **Storage**: 20GB SSD with auto-scaling capability
- **Deployment**: Multi-AZ for high availability (can be disabled for cost)
- **Security**: Deployed in private subnets with restricted access

## 🚀 Usage

1. **Initialize Terraform:**
```bash
terraform init
```

2. **Configure variables:**
```bash
# Edit terraform.tfvars
vim terraform.tfvars
```

3. **Deploy database:**
```bash
terraform plan
terraform apply
```

## ⚙️ Configuration Variables

### Required Variables
```hcl
db_password = "your-secure-password-here"  # Sensitive
```

### Optional Variables
```hcl
db_name           = "forgejo"           # Database name
db_username       = "forgejo"           # Master username
db_instance_class = "db.t3.micro"       # Instance class
allocated_storage = 20                  # Storage in GB
max_allocated_storage = 100             # Auto-scaling limit
multi_az          = false               # High availability
backup_retention_period = 7             # Backup retention days
backup_window     = "03:00-04:00"       # Backup window UTC
maintenance_window = "sun:04:00-sun:05:00" # Maintenance window
```

### Example terraform.tfvars
```hcl
db_name           = "forgejo"
db_username       = "forgejo_user"
db_password       = "MySecurePassword123!"
db_instance_class = "db.t3.micro"
multi_az          = false  # Set to true for production
```

## 📤 Outputs

- `db_endpoint` - RDS instance endpoint for connection
- `db_port` - Database port (3306)
- `db_name` - Database name
- `db_username` - Database username
- `db_instance_id` - RDS instance identifier
- `db_security_group_id` - Security group ID for database access

## 🔒 Security Configuration

### Network Security
- **Private Subnets**: Database deployed only in private subnets
- **Security Group**: Restricted to ECS container access only
- **No Public Access**: Database not accessible from internet

### Access Control
```
Inbound Rules:
- MySQL (3306) from ECS Security Group only
- No direct internet access

Outbound Rules:
- None (database doesn't need outbound connectivity)
```

### Encryption
- **At Rest**: Encryption enabled by default
- **In Transit**: SSL/TLS connections supported

## 🔧 Database Configuration

### Performance
- **Storage Type**: General Purpose SSD (gp2)
- **Auto Scaling**: Enabled up to defined maximum
- **Performance Insights**: Available for monitoring

### Backup & Recovery
- **Automated Backups**: 7-day retention period
- **Backup Window**: 03:00-04:00 UTC (low usage time)
- **Point-in-Time Recovery**: Enabled
- **Final Snapshot**: Created on deletion

### Maintenance
- **Maintenance Window**: Sunday 04:00-05:00 UTC
- **Auto Minor Version Upgrade**: Enabled for security patches
- **Major Version Upgrade**: Manual control

## 🎯 Dependencies

- **Required**: Network module (VPC, private subnets, security groups)
- **Remote State**: Reads network outputs from S3 state

### Remote State Configuration
```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "network-sg/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## 📊 Monitoring

### CloudWatch Metrics
- CPU Utilization
- Database Connections
- Free Storage Space
- Read/Write IOPS

### Recommended Alarms
```bash
# Example CloudWatch alarm creation
aws cloudwatch put-metric-alarm \
  --alarm-name "RDS-High-CPU" \
  --alarm-description "RDS CPU utilization" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

## 💰 Cost Optimization

### Current Configuration (Cost-Optimized)
- **Instance**: db.t3.micro (~$13/month)
- **Storage**: 20GB (~$2.5/month)
- **Single-AZ**: Saves ~50% compared to Multi-AZ

### Production Recommendations
```hcl
# For production workloads
db_instance_class = "db.t3.small"  # Better performance
multi_az          = true           # High availability
allocated_storage = 50             # More storage
```

## 🔍 Troubleshooting

### Connection Issues
```bash
# Test database connectivity from ECS
aws ecs execute-command \
  --cluster forgejo-cluster \
  --task <task-id> \
  --container forgejo \
  --command "mysql -h $DB_ENDPOINT -u $DB_USER -p"
```

### Check Database Status
```bash
# RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier forgejo-db
```

### Common Issues

1. **Connection Timeout**: Check security group allows ECS access
2. **Authentication Failed**: Verify username/password in terraform.tfvars
3. **Database Not Found**: Ensure db_name matches application configuration

## 🔧 Maintenance Tasks

### Manual Backup
```bash
aws rds create-db-snapshot \
  --db-instance-identifier forgejo-db \
  --db-snapshot-identifier forgejo-manual-snapshot-$(date +%Y%m%d)
```

### Scale Instance
```bash
# Update terraform.tfvars
db_instance_class = "db.t3.small"

# Apply changes
terraform plan
terraform apply
```

## 💡 Important Notes

- **Password Security**: Store database password securely (AWS Secrets Manager recommended)
- **Backup Strategy**: Automated backups + manual snapshots before major changes
- **Monitoring**: Set up CloudWatch alarms for proactive monitoring
- **State Storage**: Terraform state in S3: `db/terraform.tfstate`
- Automated backups are enabled
- Database credentials should be managed securely (consider AWS Secrets Manager)
