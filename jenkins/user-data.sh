#!/bin/bash

exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script at $(date)"

# Update system
dnf update -y

# Install Java 21
dnf install -y java-21-amazon-corretto java-21-amazon-corretto-devel

# Set JAVA_HOME
echo 'JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto' >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto

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
dnf install -y wget
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
echo "Installing Jenkins..."
dnf install -y jenkins

# Set proper ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Install useful tools
echo "Installing additional tools..."
dnf install -y nano htop git

# Install Jenkins plugins via CLI (optional)
echo "Setting up Jenkins plugins..."
JENKINS_CLI_JAR="/var/lib/jenkins/jenkins-cli.jar"

# Configure and start Jenkins
echo "Starting Jenkins..."
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start and download CLI
echo "Waiting for Jenkins to start..."
sleep 60

# Download Jenkins CLI
wget -O $JENKINS_CLI_JAR http://localhost:8080/jnlpJars/jenkins-cli.jar 2>/dev/null || echo "Jenkins CLI download will be available after setup"

# Verify Jenkins is running
systemctl status jenkins || echo "Jenkins failed to start initially"

# Create a simple status script for debugging
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
echo "Jenkins master installation completed at $(date)" >> /var/log/jenkins-install.log
echo "User-data script completed successfully at $(date)"
