# Jenkins Infrastructure Module

This module creates a simple, cost-effective Jenkins instance on AWS EC2 with persistent storage using EBS.

## Architecture

- **EC2 Instance**: t3.small (2 vCPU, 2GB RAM)
- **Storage**: 50GB EBS gp3 volume for Jenkins home
- **Security**: IP-restricted access (your IP only)
- **Built-in Agent**: Uses master node for builds (no separate agents)

## Usage

1. **Set your IP address and key pair:**
   ```bash
   # Get your public IP
   curl https://checkip.amazonaws.com
   
   # Edit terraform.tfvars
   allowed_ip_cidr = "YOUR_IP/32"
   key_pair_name = "your-key-pair"
   ```

2. **Deploy Jenkins:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Access Jenkins:**
   ```bash
   # Get Jenkins URL from output
   terraform output jenkins_url
   
   # SSH to get initial admin password
   ssh -i your-key.pem ec2-user@JENKINS_IP
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

## Variables

- `allowed_ip_cidr`: Your IP address in CIDR format (required)
- `key_pair_name`: EC2 Key Pair name for SSH access (required)
- `instance_type`: EC2 instance type (default: t3.small)
- `jenkins_home_size`: EBS volume size in GB (default: 50)

## Outputs

- `jenkins_url`: Direct URL to access Jenkins
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
