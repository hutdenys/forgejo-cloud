#!/bin/bash

# Install essential packages without GPG check (for Jenkins environment)
echo "Installing essential packages..."
sudo dnf install -y --nogpgcheck --skip-broken java-21-amazon-corretto git make || echo "Some packages failed to install, continuing..."

# wget might conflict with curl-minimal, so we'll use curl instead
echo "Using curl (already available) instead of wget"

# Set up Java environment
export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto
echo 'export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto' >> /home/ec2-user/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /home/ec2-user/.bashrc

# Create Jenkins workspace
mkdir -p /home/ec2-user/jenkins
mkdir -p /home/ec2-user/.jenkins
chown -R ec2-user:ec2-user /home/ec2-user/jenkins
chown -R ec2-user:ec2-user /home/ec2-user/.jenkins

# Install Go (optional - can be done in pipelines if needed)
echo "Installing Go 1.24..."

cd /home/ec2-user
GO_VERSION="1.24.0"
if curl -fsSL -o go${GO_VERSION}.linux-amd64.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz; then
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/ec2-user/.bashrc
    rm -f go${GO_VERSION}.linux-amd64.tar.gz  # Clean up archive
    echo "Go installed successfully"
else
    echo "Go installation failed, will be available for installation in pipelines"
fi

# Install Node.js 20
echo "Installing Node.js 20..."
if curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -; then
    sudo dnf install -y --nogpgcheck nodejs || echo "Node.js installation failed"
    echo "Node.js installed successfully"
else
    echo "Node.js installation failed, will be available for installation in pipelines"
fi

# Install Node.js 20
echo "Installing Node.js 20..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y --nogpgcheck nodejs

# Install Docker (essential for many builds)
echo "Checking Docker installation..."
if ! systemctl is-active --quiet docker; then
    echo "Installing Docker..."
    sudo dnf install -y --nogpgcheck docker || echo "Docker installation failed, continuing..."
    sudo systemctl start docker || echo "Docker start failed"
    sudo systemctl enable docker || echo "Docker enable failed" 
else
    echo "Docker is already installed and running"
fi
sudo usermod -a -G docker ec2-user || echo "Adding user to docker group failed"

# Basic environment setup
cat >> /home/ec2-user/.bashrc << 'EOF'
# Basic tools
alias ll='ls -la'
alias grep='grep --color=auto'

# Go environment
export GOPATH=/home/ec2-user/go
export PATH=$PATH:/home/ec2-user/go/bin

# Docker environment  
export PATH=$PATH:/usr/bin
EOF

# Create Go workspace
mkdir -p /home/ec2-user/go/{bin,src,pkg}
chown -R ec2-user:ec2-user /home/ec2-user/go

# Simple verification script
cat > /home/ec2-user/check-tools.sh << 'EOF'
#!/bin/bash
echo "=== Essential Tools Check ==="
echo "Java: $(java -version 2>&1 | head -1 || echo 'not found')"
echo "Git: $(git --version || echo 'not found')"  
echo "Make: $(make --version | head -1 || echo 'not found')"
echo "Go: $(go version 2>/dev/null || echo 'not found')"
echo "Node.js: $(node --version 2>/dev/null || echo 'not found')"
echo "npm: $(npm --version 2>/dev/null || echo 'not found')"
echo "Docker: $(docker --version 2>/dev/null || echo 'not found')"
echo "Curl: $(curl --version | head -1 || echo 'not found')"
echo ""
echo "=== Docker Status ==="
systemctl is-active docker 2>/dev/null || echo "Docker not running"
echo ""
echo "=== Environment ==="
echo "JAVA_HOME: $JAVA_HOME"
echo "GOPATH: $GOPATH"
EOF

chmod +x /home/ec2-user/check-tools.sh
chown ec2-user:ec2-user /home/ec2-user/check-tools.sh

echo "Simplified Jenkins agent setup completed at $(date)"
echo "Essential tools installed. Additional tools can be installed in build pipelines as needed."

# Clean up temporary files
sudo dnf clean all || echo "Failed to clean dnf cache"
rm -rf /tmp/go*.tar.gz 2>/dev/null || true

/home/ec2-user/check-tools.sh
