#!/bin/bash

# User Data Script for Venafi vSatellite Installation
# This script prepares the Amazon Linux 2 instance for vSatellite installation

# Update system packages
yum update -y

# Install required packages
yum install -y \
    curl \
    wget \
    unzip \
    docker \
    docker-compose \
    awscli

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Create directories for vSatellite
mkdir -p /opt/venafi/vsatellite
mkdir -p /var/log/venafi

# Set proper permissions
chown -R ec2-user:ec2-user /opt/venafi
chown -R ec2-user:ec2-user /var/log/venafi

# Install CloudWatch agent for monitoring
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create a basic CloudWatch config for vSatellite monitoring
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/venafi/*.log",
                        "log_group_name": "/aws/ec2/venafi-vsatellite",
                        "log_stream_name": "{instance_id}/venafi-logs"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/venafi-vsatellite",
                        "log_stream_name": "{instance_id}/system-logs"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "VenafiVSatellite",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create a setup script for easy vSatellite installation
cat > /home/ec2-user/install-vsatellite.sh << 'EOF'
#!/bin/bash

echo "=== Venafi vSatellite Installation Script ==="
echo "This script will help you download and install Venafi vSatellite"
echo ""
echo "Access Methods:"
echo "This instance is deployed in a private subnet. You can access it via:"
echo "1. AWS Instance Connect (recommended):"
echo "   aws ec2-instance-connect ssh --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --os-user ec2-user"
echo "2. Traditional SSH from within VPC"
echo "3. AWS Systems Manager Session Manager"
echo ""
echo "Steps to complete installation:"
echo "1. Download vSatellite from Venafi Support Portal"
echo "2. Upload the installation package to this server"
echo "3. Extract and run the installation"
echo ""
echo "Example commands:"
echo "# Extract vSatellite package"
echo "sudo tar -xzf vsatellite-*.tar.gz -C /opt/venafi/vsatellite"
echo ""
echo "# Run installation (follow vSatellite documentation)"
echo "cd /opt/venafi/vsatellite"
echo "sudo ./install.sh"
echo ""
echo "vSatellite will be accessible at: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "Important: Configure your security groups to allow access from your IP ranges"
EOF

chmod +x /home/ec2-user/install-vsatellite.sh
chown ec2-user:ec2-user /home/ec2-user/install-vsatellite.sh

# Create a status file to indicate completion
cat > /home/ec2-user/vsatellite-setup-status.txt << EOF
vSatellite EC2 Instance Setup Complete
======================================
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
Deployment: Private subnet (no public IP)
Project: ${project_name}
Environment: ${environment}
Setup Date: $(date)

Access Methods (Private Subnet):
=================================
1. AWS Instance Connect (Recommended):
   aws ec2-instance-connect ssh --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --os-user ec2-user

2. Traditional SSH (from within VPC):
   ssh -i ~/.ssh/your-key.pem ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

3. AWS Systems Manager Session Manager:
   aws ssm start-session --target $(curl -s http://169.254.169.254/latest/meta-data/instance-id)

Next Steps:
1. SSH to this instance using AWS Instance Connect
2. Run: ./install-vsatellite.sh for installation guidance
3. Download vSatellite from Venafi Support Portal
4. Follow Venafi vSatellite installation documentation

Required Ports:
- SSH: 22 (AWS Instance Connect + VPC access)
- HTTP: 80 (initial setup)
- HTTPS: 443 (vSatellite interface)

Logs Location: /var/log/venafi/
vSatellite Directory: /opt/venafi/vsatellite/
EOF

chown ec2-user:ec2-user /home/ec2-user/vsatellite-setup-status.txt

# Signal completion
echo "vSatellite EC2 setup completed successfully" >> /var/log/user-data.log