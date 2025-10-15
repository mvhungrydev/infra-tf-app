# Terraform Infrastructure with AWS CodeBuild and Venafi Control Plane (VCP)

This project contains Terraform infrastructure code that is designed to be built and deployed using AWS CodeBuild. The Terraform state is stored in an S3 bucket without DynamoDB state locking. The project includes integration with Venafi Control Plane (VCP) for automated certificate management with support for multiple certificate creation.

## Project Structure

```
.
├── main.tf                   # Main Terraform configuration with AWS and Venafi providers
├── variables.tf              # Input variables including Venafi VCP configuration
├── outputs.tf                # Output values for certificates and variables
├── codebuild.tf             # CodeBuild project using existing IAM role
├── buildspec.yml            # CodeBuild build specification with latest Terraform
├── terraform.tfvars.example # Example variables file
├── terraform.tfvars         # Your actual variables file (not in git)
├── .gitignore              # Git ignore patterns
└── README.md               # This file
```

## Prerequisites

1. **AWS Account**: You need an AWS account with appropriate permissions
2. **S3 Bucket**: The S3 bucket `mv-tf-pipeline-state` for Terraform state storage
3. **AWS CLI**: Configure AWS CLI with appropriate credentials
4. **Terraform**: The buildspec automatically installs the latest Terraform version
5. **Existing IAM Roles**:
   - `terraform-cicd-dev-codebuild-role` for CodeBuild execution
6. **Venafi Control Plane (VCP) Access**:
   - API key stored in AWS Secrets Manager (`pki-tppl-api-key`)
   - Access to Venafi Control Plane at `https://api.venafi.cloud`
7. **Shell Aliases**: Convenient aliases are configured for terraform commands

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

**Important Variables to Configure:**

```terraform
aws_region     = "us-east-1"
aws_account_id = "1234567891012"  # Replace with your AWS Account ID
environment    = "dev"
project_name   = "infra-tf-app"

# Certificate configuration
certificate_count  = 5
certificate_domain = "example.com"  # Replace with your domain
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

## CodeBuild Integration

### Manual Trigger

You can manually trigger the CodeBuild project through the AWS Console or AWS CLI:

```bash
aws codebuild start-build --project-name infra-tf-app-dev-terraform-build
```

### Build Process

The buildspec.yml automatically:

- Installs the latest version of Terraform dynamically
- Runs `terraform init`, `validate`, and `plan` on all branches
- Applies changes only on main/master branches with auto-approval

### Existing IAM Role

The CodeBuild project uses the existing `terraform-cicd-dev-codebuild-role` instead of creating a new one.

## Venafi Control Plane (VCP) Integration

This project is configured to work with Venafi Control Plane (VCP) for automated certificate management.

### Configuration

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

## Outputs

The project provides comprehensive outputs for both certificates and configuration variables:

### Certificate Outputs

- `certificate_common_names`: List of all certificate common names
- `certificate_ids`: List of certificate IDs from Venafi
- `certificate_dns`: List of certificate DNs
- `certificate_count`: Total number of certificates created

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
