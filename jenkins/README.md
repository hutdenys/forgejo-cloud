# Jenkins CI/CD Infrastructure Module

This module creates a cost-effective, production-ready Jenkins CI/CD server on AWS EC2 with persistent storage and secure access configuration.

## 🏗️ Architecture

- **Instance**: t3.small (2 vCPU, 2GB RAM) - optimized for CI/CD workloads
- **Storage**: 50GB EBS gp3 volume for Jenkins home directory
- **Network**: Deployed in public subnet with Elastic IP
- **Security**: IP-restricted access with configurable CIDR blocks
- **Automation**: Fully automated Jenkins installation and configuration

## 🎯 Use Cases

- **CI/CD Pipeline**: Automated builds and deployments for Forgejo repositories
- **Integration Testing**: Run tests on code commits and pull requests
- **Infrastructure Automation**: Deploy and manage AWS infrastructure changes
- **Code Quality**: Static analysis, security scanning, and compliance checks

## 🚀 Usage

### Prerequisites

1. **Create EC2 Key Pair:**
```bash
# Create new key pair
aws ec2 create-key-pair \
  --key-name jenkins-key \
  --query 'KeyMaterial' \
  --output text > jenkins-key.pem

# Set proper permissions
chmod 400 jenkins-key.pem
```

2. **Configure Variables:**
```bash
# Edit terraform.tfvars
vim terraform.tfvars
```

### Deployment Steps

1. **Initialize Terraform:**
```bash
terraform init
```

2. **Plan deployment:**
```bash
terraform plan
```

3. **Deploy Jenkins:**
```bash
terraform apply
```

4. **Get initial admin password:**
```bash
# SSH into Jenkins
make ssh-jenkins

# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## ⚙️ Configuration Variables

### Required Variables
```hcl
# Security configuration
allowed_ip_cidr = "YOUR_PUBLIC_IP/32"    # Your public IP address
key_pair_name   = "jenkins-key"          # EC2 Key Pair name
```

### Optional Variables
```hcl
# Instance configuration
instance_type     = "t3.small"           # EC2 instance type
jenkins_home_size = 50                   # EBS volume size in GB

# Network configuration  
jenkins_port = 8080                      # Jenkins web interface port

# Tags
project_name = "forgejo"
environment  = "prod"
```

### Example terraform.tfvars
```hcl
# Get your IP: curl https://checkip.amazonaws.com
allowed_ip_cidr = "203.0.113.1/32"
key_pair_name   = "jenkins-key"
instance_type   = "t3.small"
jenkins_home_size = 50

# Optional: Allow additional IPs (office, VPN, etc.)
additional_allowed_cidrs = [
  "10.0.0.0/8",      # Internal network
  "192.168.1.0/24"   # Office network
]
```

## 📤 Outputs

### Access Information
- `jenkins_url` - Direct URL to access Jenkins web interface
- `jenkins_public_ip` - Public IP address of Jenkins instance
- `jenkins_private_ip` - Private IP address for internal communication

### Infrastructure Details
- `jenkins_instance_id` - EC2 instance ID
- `jenkins_security_group_id` - Security group ID
- `jenkins_ebs_volume_id` - EBS volume ID for persistent storage

## 🔒 Security Configuration

### Network Security
```
Jenkins Security Group Rules:

Inbound:
  - SSH (22) from specified CIDR blocks
  - HTTP (8080) from specified CIDR blocks
  - NO unrestricted internet access

Outbound:
  - HTTPS (443) to 0.0.0.0/0 (for plugin downloads)
  - HTTP (80) to 0.0.0.0/0 (for updates)
  - Custom ports for AWS API calls
```

### Instance Security
- **No Password Auth**: SSH key-based authentication only
- **Automatic Updates**: Security patches applied automatically
- **Firewall**: UFW firewall configured and enabled
- **User Access**: Jenkins runs as dedicated `jenkins` user

### Data Security
- **EBS Encryption**: Storage encrypted at rest
- **Backup Strategy**: EBS snapshots for disaster recovery
- **SSL/TLS**: Can be configured with reverse proxy (nginx/ALB)

## 🛠️ Jenkins Configuration

### Pre-installed Components

The instance comes with:
- **Jenkins LTS**: Latest stable version
- **Java 17**: OpenJDK runtime environment
- **Git**: For repository operations
- **Docker**: For containerized builds (optional)
- **AWS CLI**: For AWS service integration
- **Terraform**: For infrastructure automation

### Recommended Plugins

Essential plugins for Forgejo integration:
```
- Git Plugin
- Pipeline Plugin
- AWS Pipeline Plugin
- Blue Ocean (modern UI)
- Build Timeout Plugin
- Credentials Plugin
- Workspace Cleanup Plugin
```

### Pipeline Integration

Example Jenkinsfile for Forgejo repository:
```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                git url: 'https://forgejo.pp.ua/user/repo.git'
            }
        }
        
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
        
        stage('Test') {
            steps {
                sh 'make test'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'make deploy'
            }
        }
    }
}
```

## 🎯 Dependencies

### Required Modules
- **network-sg** - VPC, public subnets, security groups

### Remote State Dependencies
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

### AWS Permissions

Jenkins instance includes IAM role with permissions for:
- **ECS**: Deploy and manage containers
- **ECR**: Push/pull Docker images
- **S3**: Store artifacts and state
- **CloudWatch**: Logging and monitoring
- **Parameter Store**: Secure credential storage

## 📊 Monitoring & Maintenance

### CloudWatch Integration
```bash
# Jenkins instance metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-xxxxx

# Custom application metrics
aws logs tail /var/log/jenkins/jenkins.log --follow
```

### Health Checks
- **Instance Status**: EC2 status checks
- **Application Health**: Jenkins web interface availability
- **Disk Usage**: EBS volume utilization monitoring

### Backup Strategy
```bash
# Create EBS snapshot
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "Jenkins backup $(date +%Y-%m-%d)"

# Automated backup with cron
echo "0 2 * * * /home/ec2-user/backup-jenkins.sh" | crontab -
```

## 💰 Cost Optimization

### Current Configuration Cost (Monthly)
- **t3.small EC2**: ~$15/month
- **50GB EBS gp3**: ~$4/month
- **Elastic IP**: Free (if attached)
- **Total**: ~$19/month

### Scaling Options
```hcl
# Production scaling
instance_type     = "t3.medium"    # 2 vCPU, 4GB RAM
jenkins_home_size = 100            # More storage

# Development scaling  
instance_type     = "t3.micro"     # 1 vCPU, 1GB RAM
jenkins_home_size = 20             # Minimal storage
```

### Cost Monitoring
```bash
# Check instance hours
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🔍 Troubleshooting

### Access Issues

1. **Cannot SSH**:
```bash
# Check security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw jenkins_security_group_id)

# Verify key pair
ssh -i jenkins-key.pem ec2-user@$(terraform output -raw jenkins_public_ip)
```

2. **Cannot Access Web Interface**:
```bash
# Check Jenkins service status
sudo systemctl status jenkins

# Check ports
sudo netstat -tlnp | grep 8080

# Check logs
sudo journalctl -u jenkins -f
```

### Performance Issues

1. **High Memory Usage**:
```bash
# Check Java heap size
sudo systemctl edit jenkins
# Add: Environment="JAVA_OPTS=-Xmx1536m"

# Monitor memory
free -h
top -p $(pgrep java)
```

2. **Disk Space**:
```bash
# Check disk usage
df -h
du -sh /var/lib/jenkins/*

# Clean old builds
find /var/lib/jenkins/jobs/*/builds/* -type d -mtime +30 -exec rm -rf {} \;
```

### Common Solutions

```bash
# Restart Jenkins
sudo systemctl restart jenkins

# Update Jenkins
sudo apt update && sudo apt upgrade jenkins

# Reset admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 🔧 Advanced Configuration

### SSL/HTTPS Setup

1. **With ALB** (Recommended):
```hcl
# Add ALB in front of Jenkins
# Terminate SSL at ALB level
# Point Route 53 to ALB
```

2. **With Nginx Reverse Proxy**:
```bash
# Install nginx
sudo apt install nginx

# Configure SSL with Let's Encrypt
sudo certbot --nginx -d jenkins.yourdomain.com
```

### Plugin Management

```bash
# Install plugins via CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin git

# Backup plugin list
curl -s "http://admin:password@localhost:8080/pluginManager/api/json?depth=1" | \
  jq -r '.plugins[].shortName' > plugins.txt
```

### Scaling for Large Teams

```hcl
# Multi-node setup
instance_type = "t3.large"        # Master node
jenkins_agents = 3                # Additional agent nodes
```

## 💡 Important Notes

- **Security First**: Always restrict access to your IP range
- **Regular Updates**: Keep Jenkins and plugins updated
- **Backup Strategy**: Implement regular EBS snapshots
- **Monitoring**: Set up CloudWatch alarms for critical metrics
- **Access Control**: Use Jenkins' built-in user management
- **State Storage**: Terraform state in S3: `jenkins/terraform.tfstate`

## 🔄 Integration Examples

### Forgejo Webhook Configuration
```json
{
  "url": "http://jenkins.forgejo.pp.ua:8080/git/notifyCommit?url=https://forgejo.pp.ua/user/repo.git",
  "content_type": "json",
  "events": ["push", "pull_request"]
}
```

### AWS Integration
```groovy
// Deploy to ECS from Jenkins
pipeline {
    agent any
    stages {
        stage('Deploy') {
            steps {
                script {
                    sh '''
                    aws ecs update-service \
                      --cluster forgejo-cluster \
                      --service forgejo \
                      --force-new-deployment
                    '''
                }
            }
        }
    }
}
```
- `jenkins_public_ip`: Public IP address
- `jenkins_ssh_command`: SSH command to connect
- `jenkins_instance_id`: EC2 instance ID

## Security

- **Network Access**: Only your IP can access port 8080 and 22
- **Encryption**: EBS volume is encrypted at rest
- **IAM**: No additional AWS permissions (minimal security footprint)

## Cost Estimation

- EC2 t3.small: ~$15/month
- EBS 50GB gp3: ~$4/month  
- Elastic IP: ~$3.6/month
- **Total: ~$22.6/month**

## Tools Included

- **Jenkins**: Latest LTS version
- **Java 17**: Required for Jenkins
- **Docker**: For containerized builds
- **Git**: Version control
- **AWS CLI**: For AWS integrations
- **Terraform**: Infrastructure management
- **kubectl**: Kubernetes management

## Post-Deployment Steps

1. **Access Jenkins UI** using the output URL
2. **Enter initial admin password** (get via SSH)
3. **Install suggested plugins**
4. **Create admin user**
5. **Configure build tools** as needed

## Maintenance

### Start/Stop Jenkins
```bash
sudo systemctl start jenkins
sudo systemctl stop jenkins
sudo systemctl restart jenkins
```

### Check Status
```bash
jenkins-status  # Custom script included
```

### Access Logs
```bash
sudo journalctl -u jenkins -f
```

## Integration with Forgejo

Jenkins can integrate with your Forgejo instance:

1. **Webhooks**: Configure Forgejo to trigger Jenkins builds
2. **Git Access**: Jenkins can clone from Forgejo repositories
3. **Network**: Both services are in the same VPC

## Backup Strategy

Since this is a simple setup without automated backups:

1. **Manual Backup**: Occasionally backup `/var/lib/jenkins`
2. **Infrastructure as Code**: This Terraform recreates the instance
3. **Job Definitions**: Store in version control (Forgejo)

## Troubleshooting

- **Can't access Jenkins**: Check security group allows your IP
- **Jenkins won't start**: Check disk space and Java installation
- **Build failures**: Ensure Docker is running and Jenkins user has permissions

## Dependencies

- Requires `network` module to be deployed first
- Needs valid EC2 Key Pair for SSH access
- Your public IP must be known for security group configuration
