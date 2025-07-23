#!/bin/bash

# Логування всіх команд
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script at $(date)"

# Update system
dnf update -y

# Install Java 17 (використовуємо Amazon Corretto)
dnf install -y java-17-amazon-corretto java-17-amazon-corretto-devel

# Set JAVA_HOME системно
echo 'JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto' >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto

# Перевірка Java
java -version || { echo "Java installation failed"; exit 1; }

# Wait for EBS volume to be available
echo "Waiting for EBS volume ${ebs_device_name}..."
while [ ! -e ${ebs_device_name} ]; do 
  echo "Waiting for EBS volume..."
  sleep 5
done

# Create Jenkins home directory
mkdir -p /var/lib/jenkins

# Format and mount EBS volume
if ! blkid ${ebs_device_name}; then
  echo "Formatting EBS volume..."
  mkfs -t xfs ${ebs_device_name}
fi

# Add to fstab for persistent mounting
echo '${ebs_device_name} /var/lib/jenkins xfs defaults,nofail 0 2' >> /etc/fstab

# Mount the volume
mount ${ebs_device_name} /var/lib/jenkins

# Install Jenkins repository and key
echo "Installing Jenkins repository..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
echo "Installing Jenkins..."
dnf install -y jenkins

# Set proper ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Install Docker (for builds)
echo "Installing Docker..."
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -a -G docker jenkins

# Install Git
dnf install -y git

# Install AWS CLI v2 with error handling
echo "Installing AWS CLI..."
dnf install -y curl unzip --allowerasing || echo "Curl installation issue, continuing..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Terraform
echo "Installing Terraform..."
wget -O terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform.zip
mv terraform /usr/local/bin/
rm terraform.zip

# Install useful tools
echo "Installing additional tools..."
dnf install -y wget nano htop --allowerasing

# Configure and start Jenkins
echo "Starting Jenkins..."
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 30

# Verify Jenkins is running
systemctl status jenkins || echo "Jenkins failed to start initially"

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

# Log completion
echo "Jenkins installation completed at $(date)" >> /var/log/jenkins-install.log
echo "User-data script completed successfully at $(date)"
