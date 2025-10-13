# Terraform Infrastructure with AWS CodeBuild and Venafi

This project contains Terraform infrastructure code that is designed to be built and deployed using AWS CodeBuild. The Terraform state is stored in an S3 bucket without DynamoDB state locking. The project includes integration with Venafi for certificate management.

## Project Structure

```
.
├── main.tf                   # Main Terraform configuration with AWS and Venafi providers
├── variables.tf              # Input variables including Venafi configuration
├── outputs.tf                # Output values
├── codebuild.tf             # CodeBuild project using existing IAM role
├── buildspec.yml            # CodeBuild build specification with latest Terraform
├── terraform.tfvars.example # Example variables file
├── terraform.tfvars         # Your actual variables file
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
   - `terraform-cicd-dev-codepipeline-role` for CodePipeline (if used)
6. **Venafi Access**: API key or credentials for your Venafi platform

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

- AWS region and environment settings
- Venafi API key and zone configuration

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

### Initialize Terraform

```bash
terraform init
```

### Validate Configuration

```bash
terraform validate
```

### Plan Changes

```bash
terraform plan
```

### Apply Changes

```bash
terraform apply
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

## Venafi Integration

This project includes the Venafi Terraform provider for certificate management. To use Venafi:

### 1. Configure Provider

Uncomment the appropriate authentication method in the Venafi provider block in `main.tf`:

```hcl
# For Venafi as a Service (VaaS)
provider "venafi" {
  api_key = var.venafi_api_key
  zone    = var.venafi_zone
}
```

### 2. Set Variables

Add your Venafi configuration to `terraform.tfvars`:

```hcl
venafi_api_key = "your-venafi-api-key"
venafi_zone    = "your-venafi-zone"
```

### 3. Example Usage

You can now use Venafi resources in your Terraform configuration:

```hcl
resource "venafi_certificate" "example" {
  common_name = "example.com"
  algorithm   = "RSA"
  rsa_bits    = 2048
}
```

## Important Notes

### State Management

- **No State Locking**: This configuration doesn't use DynamoDB for state locking as requested
- **State Storage**: Terraform state is stored in S3 bucket `mv-tf-pipeline-state` with versioning enabled
- **Concurrent Modifications**: Be careful about concurrent modifications since there's no state locking

### Security Considerations

1. **IAM Permissions**: The existing IAM roles should have minimal required permissions
2. **S3 Bucket Access**: Ensure the S3 bucket has appropriate access controls
3. **Secrets Management**: Venafi API keys and other sensitive values should be stored securely
4. **Venafi Credentials**: Use AWS Systems Manager Parameter Store or Secrets Manager for Venafi API keys

### Terraform Version

- **Dynamic Installation**: The buildspec automatically installs the latest Terraform version
- **No Version Lock**: Consider pinning to a specific version for production environments

### Customization

- Add your actual infrastructure resources to `main.tf`
- Configure Venafi provider authentication method
- Update CodeBuild environment variables as needed
- Consider adding CodePipeline for complete CI/CD workflow using `terraform-cicd-dev-codepipeline-role`

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

# List resources in state
terraform state list

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
