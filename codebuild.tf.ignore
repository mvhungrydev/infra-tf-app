# CodeBuild project for Terraform infrastructure with Venafi certificate management
resource "aws_codebuild_project" "terraform_build" {
  name         = "${var.project_name}-${var.environment}-terraform-build"
  description  = "CodeBuild project for Terraform infrastructure including Venafi certificate management"
  service_role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-codebuild-role"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # Core AWS Configuration
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "TERRAFORM_ACTION"
      value = "apply"  # Default action: "apply" or "destroy"
    }

    # Venafi Configuration
    environment_variable {
      name  = "VENAFI_TEMPLATE_ALIAS"
      value = var.venafi_template_alias
    }

    environment_variable {
      name  = "VENAFI_CLOUD_URL"
      value = var.venafi_cloud_url
    }

    # Certificate Configuration
    environment_variable {
      name  = "CERTIFICATE_COUNT"
      value = var.certificate_count
    }

    environment_variable {
      name  = "CERTIFICATE_DOMAIN"
      value = var.certificate_domain
    }

    environment_variable {
      name  = "CERTIFICATE_ALGORITHM"
      value = var.certificate_algorithm
    }

    environment_variable {
      name  = "CERTIFICATE_RSA_BITS"
      value = var.certificate_rsa_bits
    }

    environment_variable {
      name  = "CERTIFICATE_VALID_DAYS"
      value = var.certificate_valid_days
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "buildspec.yml"

    git_submodules_config {
      fetch_submodules = false
    }
  }

  # Set default source version to main branch
  source_version = "main"

  tags = {
    Name        = "${var.project_name}-${var.environment}-terraform-build"
    Environment = var.environment
    Purpose     = "Terraform Infrastructure Deployment"
  }
}

# GitHub webhook for automatic builds
resource "aws_codebuild_webhook" "github_webhook" {
  project_name = aws_codebuild_project.terraform_build.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/main$"
    }
  }

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED"
    }
  }

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_UPDATED"
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}