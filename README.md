# Terraform Infrastructure with AWS CodeBuild, Venafi Control Plane (VCP), and EC2 vSatellite

This project contains Terraform infrastructure code that is designed to be built and deployed using AWS CodeBuild. The Terraform state is stored in an S3 bucket without DynamoDB state locking. The project includes integration with Venafi Control Plane (VCP) for automated certificate management with support for multiple certificate creation, plus EC2 instance deployment for Venafi vSatellite with automatic VPC/subnet discovery.

## Project Structure

```
.
├── main.tf                    # Main Terraform configuration with AWS and Venafi providers
├── variables.tf               # Input variables including Venafi VCP and EC2 configuration
├── outputs.tf                 # Output values for certificates, variables, and EC2 instance details
├── ec2-vsatellite.tf         # EC2 instance configuration for Venafi vSatellite with VPC discovery
├── user-data-vsatellite.sh   # User data script for vSatellite installation
├── codebuild.tf              # CodeBuild project using existing IAM role
├── buildspec.yml             # CodeBuild build specification with latest Terraform
├── terraform.tfvars.example  # Example variables file
├── terraform.tfvars          # Your actual variables file (not in git)
├── .gitignore               # Git ignore patterns
└── README.md                # This file
```

## Prerequisites

### AWS Account & Permissions

1. **AWS Account**: You need an AWS account with appropriate permissions
2. **AWS CLI**: Configure AWS CLI with appropriate credentials and region
   ```bash
   aws configure
   # Set your Access Key ID, Secret Access Key, Default region (us-east-1), and output format
   ```
3. **AWS Account ID**: Know your 12-digit AWS Account ID for variable configuration

### Infrastructure Storage & State Management

4. **S3 Bucket**: The S3 bucket `mv-tf-pipeline-state` for Terraform state storage
   - Must exist with versioning enabled
   - Proper IAM permissions for read/write access
5. **No DynamoDB**: This configuration doesn't use DynamoDB for state locking (as requested)

### Development Tools

6. **Terraform**: The buildspec automatically installs the latest Terraform version for CodeBuild

   - For local development: Install Terraform >= 1.0 on your machine

   ```bash
   # macOS with Homebrew
   brew install terraform

   # Or download from https://terraform.io/downloads
   ```

7. **Git**: Version control system for code management
8. **Code Editor**: VS Code, IntelliJ, or similar with Terraform syntax support

### AWS IAM Roles & Permissions

9. **Existing CodeBuild IAM Role**: `terraform-cicd-dev-codebuild-role`
   - Must have permissions for EC2, VPC, S3, Secrets Manager, and other AWS services
   - Must be able to assume roles and create/modify infrastructure
10. **Local Development Permissions**: Your AWS user/role must have permissions for:
    - EC2 (instances, security groups, key pairs)
    - VPC (describe VPCs, subnets, route tables)
    - S3 (state bucket access)
    - Secrets Manager (read pki-tppl-api-key)
    - IAM (read roles, policies)

### Venafi Control Plane (VCP) Requirements

11. **Venafi VCP Account**: Active account with Venafi Control Plane
    - Access to `https://api.venafi.cloud`
    - Valid API key with certificate creation permissions
12. **Venafi API Key Storage**: API key stored in AWS Secrets Manager
    - Secret name: `pki-tppl-api-key`
    - Secret value: Your Venafi VCP API key
    ```bash
    # Create secret in AWS Secrets Manager
    aws secretsmanager create-secret \
        --name pki-tppl-api-key \
        --description "Venafi VCP API Key" \
        --secret-string "your-venafi-api-key-here"
    ```
13. **Certificate Domain**: Valid domain name you own for certificate generation

### Existing AWS Infrastructure

14. **VPC**: Existing VPC containing "tf-infra-networking" in the name
    - Must have proper tags: `Name` and `Environment=dev`
    - Example: `mv-tf-infra-networking-vpc` with `Environment=dev` tag
15. **Subnets**: Private subnets within the VPC
    - Either named with "private"/"Private" in the name
    - Or configured as private subnets (route tables without internet gateway)
16. **Security Groups**: Existing security groups within the VPC (optional)
    - The configuration will discover existing security groups
    - Falls back to VPC default security group if none found
17. **NAT Gateway/Instance**: For private subnet internet access (required for vSatellite to communicate with Venafi Cloud)

### SSH Access (Optional)

18. **EC2 Key Pair**: SSH key pair for traditional SSH access (optional)
    - Can be created in AWS Console or CLI
    - Alternatively, use AWS Instance Connect (no key pair needed)
    ```bash
    # Create key pair
    aws ec2 create-key-pair \
        --key-name my-terraform-key \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/my-terraform-key.pem
    chmod 400 ~/.ssh/my-terraform-key.pem
    ```

### Network Access

19. **VPC Connectivity**: Method to access private subnet resources
    - VPN connection to your AWS VPC, OR
    - Bastion host/jump server, OR
    - AWS VPC peering, OR
    - AWS Direct Connect
20. **AWS Instance Connect**: For secure SSH access to private instances
    - Enabled in us-east-1 region
    - No additional setup required

### Development Environment

21. **Shell Environment**: bash, zsh, or compatible shell for aliases
22. **Internet Access**: For downloading Terraform, accessing Venafi Cloud, and AWS APIs

### Monitoring & Logging (Recommended)

23. **CloudWatch**: For monitoring CodeBuild logs and EC2 instances
24. **VPC Flow Logs**: For network troubleshooting (optional)

### Validation Commands

Before proceeding, verify your setup:

```bash
# Test AWS CLI access
aws sts get-caller-identity

# Verify S3 bucket access
aws s3 ls s3://mv-tf-pipeline-state

# Check Venafi API key in Secrets Manager
aws secretsmanager get-secret-value --secret-id pki-tppl-api-key

# Verify VPC exists
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*tf-infra-networking*"

# Test Terraform installation
terraform version
```

## Setup

### 1. S3 Bucket for Terraform State

The S3 bucket `mv-tf-pipeline-state` is already configured in the backend. Ensure it exists and has versioning enabled:

```bash
aws s3api put-bucket-versioning \
    --bucket mv-tf-pipeline-state \
    --versioning-configuration Status=Enabled
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values, including:

- AWS region, account ID, and environment settings
- Venafi API key and VCP configuration
- Certificate domain and count preferences
- EC2 vSatellite configuration including key pair for SSH access

**Important Variables to Configure:**

```terraform
aws_region     = "us-east-1"
aws_account_id = "1234567891012"  # Replace with your AWS Account ID
environment    = "dev"
project_name   = "terraform-cicd"

# Certificate configuration
certificate_count  = 5
certificate_domain = "example.com"  # Replace with your domain

# EC2 vSatellite configuration
key_pair_name              = "my-key-pair"        # REQUIRED: Your EC2 key pair
vsatellite_instance_type   = "t3.large"
vsatellite_root_volume_size = 50
```

### 3. Venafi Configuration

Configure the Venafi provider in `main.tf` by uncommenting the appropriate authentication method:

**For Venafi as a Service (VaaS):**

```hcl
provider "venafi" {
  api_key = var.venafi_api_key
  zone    = var.venafi_zone
}
```

### 4. IAM Roles

The project uses existing IAM roles:

- **`terraform-cicd-dev-codebuild-role`**: Used by CodeBuild for execution
- **`terraform-cicd-dev-codepipeline-role`**: Available for CodePipeline integration

Ensure these roles have proper permissions for your infrastructure needs.

## Local Development

### Shell Aliases

For convenience, the following aliases are configured in your shell:

| Alias | Command                           | Purpose                              |
| ----- | --------------------------------- | ------------------------------------ |
| `tf`  | `terraform`                       | Base terraform command               |
| `tfp` | `terraform plan`                  | Show execution plan                  |
| `tfa` | `terraform apply -auto-approve`   | Apply changes automatically          |
| `tfd` | `terraform destroy -auto-approve` | Destroy infrastructure automatically |

These aliases are automatically configured in:

- `~/.zshrc` (for zsh)
- `~/.bashrc` (for bash)
- `~/.bash_profile` (for bash on macOS)

### Initialize Terraform

```bash
terraform init
# or use alias
tf init
```

### Validate Configuration

```bash
terraform validate
# or use alias
tf validate
```

### Plan Changes

```bash
terraform plan
# or use alias
tfp
```

### Apply Changes

```bash
terraform apply
# or use alias
tfa
```

### Destroy Infrastructure

```bash
terraform destroy
# or use alias
tfd
```

## CodeBuild Integration with GitHub

This project is integrated with GitHub for automatic CI/CD builds. The CodeBuild project is configured to automatically trigger builds on GitHub events.

### GitHub Webhook Configuration

The CodeBuild project automatically responds to:

1. **Push to main branch**: Triggers infrastructure deployment
2. **Pull Request creation**: Runs terraform plan for validation
3. **Pull Request updates**: Re-runs plan with latest changes

### Automatic Triggers

```yaml
# Automatic triggers configured:
- Push to main branch → Plan and Apply infrastructure
- Pull Requests → Plan only (validation)
- Feature branches → Plan only (testing)
```

### Manual Trigger

You can also manually trigger the CodeBuild project:

```bash
# Apply infrastructure (default action)
aws codebuild start-build --project-name infra-tf-app-dev-terraform-build

# Destroy infrastructure
aws codebuild start-build \
  --project-name infra-tf-app-dev-terraform-build \
  --environment-variables-override name=TERRAFORM_ACTION,value=destroy
```

### GitHub Repository

- **Repository**: `https://github.com/mvhungrydev/infra-tf-app.git`
- **Default Branch**: `main`
- **Webhook**: Automatically configured for CI/CD

### Build Process

The buildspec.yml automatically:

- Installs the latest version of Terraform dynamically
- Runs `terraform init`, `validate`, and `plan` on all branches
- **Main/Master branches**: Executes terraform apply or destroy based on `TERRAFORM_ACTION`
- **Feature branches**: Shows plan only (no infrastructure changes)
- Supports both `apply` and `destroy` actions via environment variables

### Terraform Actions

| **Action** | **Trigger**         | **Behavior**                       |
| ---------- | ------------------- | ---------------------------------- |
| `apply`    | Push to main        | Plans and applies infrastructure   |
| `destroy`  | Manual with env var | Plans and destroys infrastructure  |
| Plan only  | Pull requests       | Validates changes without applying |

### Existing IAM Role

The CodeBuild project uses the existing `terraform-cicd-dev-codebuild-role` instead of creating a new one.

## EC2 vSatellite Deployment

This project automatically deploys an EC2 instance for Venafi vSatellite with intelligent infrastructure discovery.

### Infrastructure Discovery

The vSatellite deployment automatically discovers existing infrastructure:

#### VPC Discovery

```hcl
# Finds VPC containing 'tf-infra-networking' in name and matching environment
data "aws_vpcs" "infra_tf" {
  tags = {
    Name        = "*tf-infra-networking*"
    Environment = var.environment  # "dev"
  }
}
```

#### Subnet Discovery

- **Primary**: Searches for subnets with "private" or "Private" in the name
- **Fallback**: Analyzes route tables to identify private subnets (no internet gateway routes)
- **Selection**: Automatically selects the first available private subnet

#### Security Group Discovery

- **Primary**: Searches for existing security groups containing patterns like:
  - `*tf-infra*`
  - `*infra-tf*`
  - `*mv-tf*`
  - `*${project_name}*`
- **Fallback**: Uses VPC default security group if no specific security group found

### EC2 Instance Configuration

```hcl
resource "aws_instance" "vsatellite" {
  ami                     = data.aws_ami.amazon_linux.id  # Latest Amazon Linux 2
  instance_type           = var.vsatellite_instance_type  # t3.large (recommended)
  key_name               = var.key_pair_name              # Your SSH key pair
  subnet_id              = local.selected_private_subnet  # Auto-discovered private subnet
  vpc_security_group_ids = [data.aws_security_group.vsatellite.id]  # Auto-discovered security group

  # Root volume: 50GB GP3 encrypted storage
  # User data: Automated vSatellite installation script
  # Instance Connect: Enabled for secure SSH access
}
```

### Access Methods

After deployment, you can access the vSatellite instance using:

1. **AWS Instance Connect** (Recommended for private subnets):

   ```bash
   aws ec2-instance-connect ssh --instance-id i-1234567890abcdef0 --os-user ec2-user
   ```

2. **Traditional SSH** (if key pair configured):

   ```bash
   ssh -i ~/.ssh/your-key.pem ec2-user@<private-ip>
   ```

3. **Web Interface** (from within VPC):
   ```bash
   https://<private-ip>  # After vSatellite installation completes
   ```

### Security Features

- **Private Subnet Deployment**: Instance placed in private subnet with no direct internet access
- **AWS Instance Connect Integration**: Secure SSH without managing SSH keys
- **Encrypted Storage**: GP3 volumes with encryption enabled
- **Security Group Discovery**: Uses existing security groups for proper network access
- **IMDSv2 Required**: Instance metadata service v2 enforced for security

## Venafi Control Plane (VCP) Integration

This project is configured to work with Venafi Control Plane (VCP) for automated certificate management.

The Venafi provider is configured to use VCP:

```hcl
provider "venafi" {
  api_key = var.venafi_api_key  # Retrieved from AWS Secrets Manager
  url     = var.venafi_cloud_url # https://api.venafi.cloud
  zone    = local.venafi_zone   # Environment-specific zone
}
```

### Zone Configuration

The project uses conditional zone logic based on environment and AWS account ID:

- **Production**: `aws_12345_${var.aws_account_id}_prod\<template_alias>`
- **Development**: `aws_12345_${var.aws_account_id}_lle\<template_alias>`

The AWS account ID is now configurable via the `aws_account_id` variable.

### Multiple Certificate Creation

The project creates multiple certificates using the count parameter:

```hcl
resource "venafi_certificate" "certificates" {
  count       = var.certificate_count  # Default: 5
  common_name = "cert-${random_id.cert_suffix[count.index].hex}.${var.certificate_domain}"
  algorithm   = var.certificate_algorithm  # RSA
  rsa_bits    = var.certificate_rsa_bits   # 2048
  valid_days  = var.certificate_valid_days # 90

  san_dns = [
    "alt-${random_id.cert_suffix[count.index].hex}.${var.certificate_domain}",
    "www-${random_id.cert_suffix[count.index].hex}.${var.certificate_domain}"
  ]

  tags = [
    "Environment: ${var.environment}"
  ]
}
```

### Secret Management

The Venafi API key is stored in AWS Secrets Manager:

- **Secret Name**: `pki-tppl-api-key`
- **Retrieval**: Automatically retrieved in CodeBuild via buildspec.yml
- **Local Development**: Set via environment variable `TF_VAR_venafi_api_key`

### Current Configuration

Based on `terraform.tfvars`:

| Variable                 | Value                    | Description                      |
| ------------------------ | ------------------------ | -------------------------------- |
| `aws_account_id`         | 123456789102             | AWS Account ID for Venafi zones  |
| `certificate_count`      | 5                        | Number of certificates to create |
| `certificate_domain`     | example.com              | Base domain for certificates     |
| `certificate_algorithm`  | RSA                      | Certificate algorithm            |
| `certificate_rsa_bits`   | 2048                     | RSA key size                     |
| `certificate_valid_days` | 90                       | Certificate validity period      |
| `venafi_template_alias`  | Default                  | Venafi issuing template          |
| `venafi_cloud_url`       | https://api.venafi.cloud | VCP API endpoint                 |

### Outputs

The project provides comprehensive outputs for certificates, configuration variables, and EC2 infrastructure:

### Certificate Outputs

- `certificate_common_names`: List of all certificate common names
- `certificate_ids`: List of certificate IDs from Venafi
- `certificate_dns`: List of certificate DNs
- `certificate_count`: Total number of certificates created

### EC2 vSatellite Outputs

- `vsatellite_instance_id`: EC2 instance ID for the vSatellite
- `vsatellite_private_ip`: Private IP address of the instance
- `vsatellite_subnet_id`: Subnet where the instance is deployed
- `vsatellite_vpc_id`: VPC where the instance is deployed
- `vsatellite_ssh_command`: Ready-to-use SSH command (if key pair configured)
- `vsatellite_instance_connect_command`: AWS Instance Connect command
- `vsatellite_web_url`: Web interface URL (accessible from within VPC)
- `vsatellite_security_group_id`: Security group ID attached to the instance
- `quick_access_summary`: Consolidated object with all access methods

### Infrastructure Discovery Outputs

- `discovered_vpc_cidr`: CIDR block of the discovered VPC
- `discovered_vpc_name`: Name of the discovered VPC
- `available_private_subnets`: List of all discovered private subnets

### Variable Outputs (excluding sensitive API key)

- **AWS Configuration**: `aws_region`, `aws_account_id`, `environment`, `project_name`
- **Venafi Configuration**: `venafi_zone`, `venafi_template_alias`, `venafi_cloud_url`
- **Certificate Configuration**: `certificate_count_config`, `certificate_domain`, `certificate_algorithm`, `certificate_rsa_bits`, `certificate_valid_days`

View outputs with:

```bash
terraform output
# or specific output
terraform output certificate_common_names
terraform output aws_account_id
```

## Recent Updates

### Latest Changes

- ✅ **AWS Account ID Variable**: The AWS account ID is now configurable via `aws_account_id` variable
- ✅ **Dynamic Zone Construction**: Venafi zones are dynamically built using the account ID variable
- ✅ **Enhanced Outputs**: Added `aws_account_id` to the output variables
- ✅ **Infrastructure Management**: Complete lifecycle management with `tfa` (apply) and `tfd` (destroy) aliases

### Variable Configuration Improvements

- **Flexibility**: Easy to switch between AWS accounts by changing one variable
- **Maintainability**: Account-specific configurations are centrally managed
- **Reusability**: Same codebase can be used across different AWS environments

## Example Deployment Results

After successful deployment, you'll see output similar to:

```
certificate_common_names = [
  "cert-6a68b58c.example.com",
  "cert-01b3f625.example.com",
  "cert-80efef15.example.com",
  "cert-8537c08d.example.com",
  "cert-152f8df0.example.com",
]
certificate_count = 5
certificate_ids = [
  "efa93770-a969-11f0-895f-f1b4c4ed3cf0",
  "efb608b0-a969-11f0-b70c-2979defd1da2",
  "efab5a50-a969-11f0-a8b5-6181a1b32af3",
  "efb4a920-a969-11f0-9a93-fd9ab6875cb4",
  "efb54560-a969-11f0-895f-f1b4c4ed3cf0",
]
```

**Note**: The above example shows successful deployment output. Infrastructure was recently destroyed using `tfd` command and can be recreated anytime with the new AWS account ID variable configuration.

## Infrastructure Lifecycle

### Current Status

- **Infrastructure State**: Destroyed (clean slate)
- **Configuration**: Updated with AWS account ID variable
- **Ready for Deployment**: Use `tfa` to deploy with new variable structure

### Deployment Workflow

1. **Plan**: `tfp` - Review changes before applying
2. **Apply**: `tfa` - Deploy infrastructure automatically
3. **Destroy**: `tfd` - Clean up resources when needed

## API Integration Capabilities

Terraform supports making API calls to external services during apply operations using several methods:

### 1. HTTP Provider

Make REST API calls to external services for:

- Service discovery and dynamic configuration
- IP whitelist management
- Certificate validation and registration
- Compliance reporting and audit trails

### 2. External Data Source

Execute scripts that call APIs for:

- Feature flag integration
- External health checks
- Dynamic scaling parameters

### 3. Local/Remote Exec Provisioners

Run API calls as part of provisioning for:

- Webhook notifications
- External system registration
- Post-deployment actions

Example use case for your certificate setup:

```hcl
# Notify external system about certificate creation
data "http" "cert_registration" {
  url = "https://cert-inventory.company.com/api/certificates/register"
  method = "POST"
  request_body = jsonencode({
    certificate_id = venafi_certificate.certificates[0].certificate_id
    environment    = var.environment
  })
}
```

### State Management

- **No State Locking**: This configuration doesn't use DynamoDB for state locking as requested
- **State Storage**: Terraform state is stored in S3 bucket `mv-tf-pipeline-state` with versioning enabled
- **Concurrent Modifications**: Be careful about concurrent modifications since there's no state locking

### Security Considerations

1. **IAM Permissions**: The existing IAM roles should have minimal required permissions
2. **S3 Bucket Access**: Ensure the S3 bucket has appropriate access controls
3. **Secrets Management**:
   - Venafi API key stored in AWS Secrets Manager (`pki-tppl-api-key`)
   - Retrieved automatically in CodeBuild
   - Use environment variables for local development: `export TF_VAR_venafi_api_key="your-key"`
4. **Venafi VCP Authentication**: Ensure proper API key permissions for certificate operations
5. **Sensitive Information Protection**:
   - Never commit real AWS account IDs, API keys, or domains to version control
   - Use placeholder values in configuration files
   - Set actual values via environment variables or AWS Secrets Manager

### Terraform Version

- **Dynamic Installation**: The buildspec automatically installs the latest Terraform version
- **No Version Lock**: Consider pinning to a specific version for production environments

### Customization

- Add your actual infrastructure resources to `main.tf`
- Venafi VCP provider is pre-configured with environment-specific zones
- Update certificate count and domain configuration in `terraform.tfvars`
- CodeBuild environment variables configured for VCP API key retrieval
- Consider adding additional API integrations using HTTP provider

## Deployment Strategy

The buildspec.yml is configured to:

1. **Plan on all branches**: Run `terraform plan` on every build
2. **Apply on main/master**: Only run `terraform apply` when building the main or master branch
3. **Auto-approve**: Uses `-auto-approve` flag (consider removing for production)

## Troubleshooting

### Common Issues

1. **S3 Access Denied**: Ensure the CodeBuild role has proper S3 permissions
2. **Terraform Init Fails**: Check the S3 bucket name and region in the backend configuration
3. **Build Failures**: Check CloudWatch Logs for the CodeBuild project

### Useful Commands

```bash
# Check Terraform state
terraform show
# or with alias
tf show

# List resources in state
terraform state list
# or with alias
tf state list

# View specific outputs
terraform output certificate_common_names
tf output certificate_ids

# Quick plan and apply workflow
tfp  # terraform plan
tfa  # terraform apply -auto-approve

# Quick destroy
tfd  # terraform destroy -auto-approve

# Import existing resources
terraform import aws_s3_bucket.example your-bucket-name
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Test locally with `terraform plan`
4. Push to trigger CodeBuild
5. Review the build logs
6. Merge to main/master for deployment
