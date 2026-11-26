# Input variable for the AWS Region (defaults to N. Virginia / us-east-1).
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# Input variable used as a naming prefix for IAM roles, Lambda, Glue, and Athena resources.
variable "project_name" {
  description = "Prefix used for naming resources"
  type        = string
  default     = "csv-pipeline"
}

# Required variable (supplied via terraform.tfvars) to ensure our 3 S3 bucket names are globally unique.
variable "bucket_prefix" {
  description = "Globally unique prefix for the 3 S3 buckets"
  type        = string
}
