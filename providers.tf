# Configures the minimum Terraform CLI version and downloads the required plugins (providers).
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    # AWS provider: lets Terraform create and manage AWS services (S3, Lambda, Glue, IAM, Athena).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # Archive provider: lets Terraform automatically zip our Python script before uploading to Lambda.
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
}

# Tells Terraform which AWS Region to deploy into and automatically applies tags to every resource.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "Lab"
      ManagedBy   = "Terraform"
    }
  }
}
