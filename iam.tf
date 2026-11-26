# ==============================================================================
# PART 1: IAM EXECUTION ROLE FOR AWS LAMBDA (Least-Privilege)
# ==============================================================================

# Trust Policy: Allows the AWS Lambda service to assume ("wear") this IAM role.
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [join(".", ["lambda", "amazonaws", "com"])]
    }
  }
}

# Creates the IAM Role for our CSV-cleaning Lambda function.
resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Attaches AWS's standard logging policy so Lambda can write print() output and errors to CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Least-Privilege Policy: Lambda can ONLY read from the Raw bucket and write to the Processed bucket.
data "aws_iam_policy_document" "lambda_s3_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.raw.arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.processed.arn}/*"]
  }
}

# Attaches the custom S3 permissions above to the Lambda role.
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "${var.project_name}-lambda-s3"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_s3_access.json
}

# ==============================================================================
# PART 2: IAM SERVICE ROLE FOR AWS GLUE (Crawlers + ETL Job)
# ==============================================================================

# Trust Policy: Allows the AWS Glue service to assume this IAM role.
data "aws_iam_policy_document" "glue_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [join(".", ["glue", "amazonaws", "com"])]
    }
  }
}

# Creates the IAM Role used by both Glue Crawlers and the Glue ETL Job.
resource "aws_iam_role" "glue_role" {
  name               = "${var.project_name}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

# Attaches AWS's managed Glue policy (grants permissions for Data Catalog tables, CloudWatch logs, and Glue jobs).
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom Least-Privilege Policy: Grants Glue read/write access ONLY to the Processed and Final buckets.
data "aws_iam_policy_document" "glue_s3_access" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.processed.arn,
      "${aws_s3_bucket.processed.arn}/*",
      aws_s3_bucket.final.arn,
      "${aws_s3_bucket.final.arn}/*"
    ]
  }
}

# Attaches the custom S3 permissions above to the Glue role.
resource "aws_iam_role_policy" "glue_s3_policy" {
  name   = "${var.project_name}-glue-s3"
  role   = aws_iam_role.glue_role.id
  policy = data.aws_iam_policy_document.glue_s3_access.json
}
