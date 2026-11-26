# 1. RAW BUCKET: Landing zone where raw, messy CSV files are uploaded to start the pipeline.
# force_destroy = true lets "terraform destroy" delete the bucket even if files are inside.
resource "aws_s3_bucket" "raw" {
  bucket        = "${var.bucket_prefix}-raw"
  force_destroy = true
}

# Security best practice: keeps the Raw bucket 100% private (blocks all public internet access).
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. PROCESSED BUCKET: Stores cleaned CSV files created by Lambda AND holds our Glue PySpark script.
resource "aws_s3_bucket" "processed" {
  bucket        = "${var.bucket_prefix}-processed"
  force_destroy = true
}

# Keeps the Processed bucket 100% private.
resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. FINAL BUCKET: Stores the aggregated summary CSV created by AWS Glue + Athena query results.
resource "aws_s3_bucket" "final" {
  bucket        = "${var.bucket_prefix}-final"
  force_destroy = true
}

# Keeps the Final bucket 100% private.
resource "aws_s3_bucket_public_access_block" "final" {
  bucket                  = aws_s3_bucket.final.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Uploads our local PySpark ETL script into S3 so AWS Glue can execute it when we run the ETL job.
# etag = filemd5(...) ensures Terraform re-uploads the script automatically if you ever edit it.
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.processed.id
  key    = "scripts/sales_summary_etl.py"
  source = "${path.module}/glue/sales_summary_etl.py"
  etag   = filemd5("${path.module}/glue/sales_summary_etl.py")
}
