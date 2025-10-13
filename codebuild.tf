# CodeBuild project for Terraform
resource "aws_codebuild_project" "terraform_build" {
  name          = "${var.project_name}-${var.environment}-terraform-build"
  description   = "CodeBuild project for Terraform infrastructure"
  service_role  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/terraform-cicd-dev-codebuild-role"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}