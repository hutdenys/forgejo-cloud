#!/bin/bash

# Update system
dnf update -y

# Install Java 17 (required for Jenkins)
dnf install -y java-17-openjdk java-17-openjdk-devel

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Wait for EBS volume to be available
while [ ! -e ${ebs_device_name} ]; do 
  echo "Waiting for EBS volume..."
  sleep 5
done

# Create Jenkins home directory
mkdir -p /var/lib/jenkins

# Format and mount EBS volume
if ! blkid ${ebs_device_name}; then
  mkfs -t xfs ${ebs_device_name}
fi

# Add to fstab for persistent mounting
echo '${ebs_device_name} /var/lib/jenkins xfs defaults,nofail 0 2' >> /etc/fstab

# Mount the volume
mount ${ebs_device_name} /var/lib/jenkins

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

# Set proper ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Install Docker (for builds)
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -a -G docker jenkins

# Install Git
dnf install -y git

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
dnf install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Terraform
wget -O terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform.zip
mv terraform /usr/local/bin/
rm terraform.zip

# Configure Jenkins
systemctl enable jenkins
systemctl start jenkins

# Install useful tools
dnf install -y wget curl nano htop

# Create a simple status script
cat > /usr/local/bin/jenkins-status << 'EOF'
#!/bin/bash
echo "=== Jenkins Status ==="
systemctl status jenkins --no-pager
echo ""
echo "=== Jenkins URL ==="
echo "http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "=== Initial Admin Password ==="
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  cat /var/lib/jenkins/secrets/initialAdminPassword
else
  echo "Password file not found. Jenkins may still be starting..."
fi
EOF

chmod +x /usr/local/bin/jenkins-status

# Wait for Jenkins to start and create initial password
sleep 30

# Log completion
echo "Jenkins installation completed at $(date)" >> /var/log/jenkins-install.log
