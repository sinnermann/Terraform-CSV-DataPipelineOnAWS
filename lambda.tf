# Automatically packages lambda/clean_raw_csv.py into a .zip file during "terraform apply".
data "archive_file" "clean_csv_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/clean_raw_csv.py"
  output_path = "${path.module}/.terraform/clean_raw_csv.zip"
}

# Creates the Python 3.13 Lambda function and passes the Processed bucket name via Environment Variables.
resource "aws_lambda_function" "clean_csv" {
  function_name    = "${var.project_name}-clean-raw-csv"
  role             = aws_iam_role.lambda_role.arn
  handler          = "clean_raw_csv.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.clean_csv_zip.output_path
  source_code_hash = data.archive_file.clean_csv_zip.output_base64sha256

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.id
    }
  }
}

# Resource-based policy: Explicitly grants our Raw S3 bucket permission to trigger this Lambda function.
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3RawBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clean_csv.function_name
  principal     = join(".", ["s3", "amazonaws", "com"])
  source_arn    = aws_s3_bucket.raw.arn
}

# S3 Event Notification: Watches the Raw bucket and fires Lambda whenever a ".csv" file is uploaded.
# depends_on ensures the permission above is created BEFORE S3 tries to validate the trigger.
resource "aws_s3_bucket_notification" "raw_csv_upload" {
  bucket     = aws_s3_bucket.raw.id
  depends_on = [aws_lambda_permission.allow_s3]

  lambda_function {
    lambda_function_arn = aws_lambda_function.clean_csv.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }
}
