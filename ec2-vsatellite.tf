# Venafi vSatellite EC2 Instance Configuration

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source to find VPC containing 'tf-infra' in the name AND matching environment
data "aws_vpcs" "infra_tf" {
  tags = {
    Name        = "*tf-infra*"
    Environment = var.environment
  }
}

# Data source to get the VPC details
data "aws_vpc" "infra_tf" {
  id = data.aws_vpcs.infra_tf.ids[0]
}

# Data source to find private subnets in the infra-tf VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.infra_tf.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*", "*Private*"]
  }
}

# Fallback: if no subnets with 'private' in name, get all subnets and filter by route table
data "aws_subnets" "all_subnets" {
  count = length(data.aws_subnets.private.ids) == 0 ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.infra_tf.id]
  }
}

# Data source to identify private subnets by checking route tables (no internet gateway route)
data "aws_route_table" "subnet_routes" {
  count     = length(data.aws_subnets.private.ids) == 0 ? length(data.aws_subnets.all_subnets[0].ids) : 0
  subnet_id = data.aws_subnets.all_subnets[0].ids[count.index]
}

# Local to determine the private subnet to use
locals {
  # Use subnets with 'private' in name if available, otherwise find private subnets by route table
  private_subnet_ids = length(data.aws_subnets.private.ids) > 0 ? data.aws_subnets.private.ids : [
    for i, rt in data.aws_route_table.subnet_routes : data.aws_subnets.all_subnets[0].ids[i]
    if !contains([for route in rt.routes : route.gateway_id if can(route.gateway_id)], "igw-*")
  ]
  
  # Select the first available private subnet
  selected_private_subnet = local.private_subnet_ids[0]
}

# Data source to find existing security group containing the project name
data "aws_security_groups" "existing_sg" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.infra_tf.id]
  }

  filter {
    name   = "group-name"
    values = ["*tf-infra*"]
  }
}

# Data source to get the specific security group details
data "aws_security_group" "vsatellite" {
  id = data.aws_security_groups.existing_sg.ids[0]
}

# User data script for vSatellite installation
locals {
  user_data = base64encode(templatefile("${path.module}/user-data-vsatellite.sh", {
    project_name = var.project_name
    environment  = var.environment
  }))
}

# EC2 Instance for Venafi vSatellite
resource "aws_instance" "vsatellite" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = var.vsatellite_instance_type
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null
  subnet_id              = local.selected_private_subnet
  vpc_security_group_ids = [data.aws_security_group.vsatellite.id]
  
  # Enable detailed monitoring for dev environment
  monitoring = true
  
  # User data for initial setup
  user_data = local.user_data

  # Root volume configuration optimized for vSatellite
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.vsatellite_root_volume_size
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-vsatellite-root"
    }
  }

  # Instance metadata options (security best practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.vsatellite_name}"
    Purpose     = "Venafi vSatellite"
    VenafiRole  = "vSatellite"
  }
}

# Note: No Elastic IP for private subnet instance
# Access will be through VPC peering, VPN, or bastion host