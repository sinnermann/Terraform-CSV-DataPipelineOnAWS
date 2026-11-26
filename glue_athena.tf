# 1. GLUE DATA CATALOG DATABASE: Logical container holding our schema tables for Glue and Athena.
resource "aws_glue_catalog_database" "sales_db" {
  name = "csv_sales_db"
}

# 2. PROCESSED CRAWLER: Scans the Processed bucket to infer CSV columns/types and creates a Catalog table.
# exclusions = ["scripts/**"] ensures it ignores our PySpark script folder and only crawls cleaned CSVs.
resource "aws_glue_crawler" "processed" {
  name          = "${var.project_name}-processed-crawler"
  database_name = aws_glue_catalog_database.sales_db.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path       = "s3://${aws_s3_bucket.processed.id}/"
    exclusions = ["scripts/**"]
  }
}

# 3. GLUE ETL JOB: Runs our PySpark script to sum revenue & count orders by category, saving to Final bucket.
# Cost-safe settings: 2 x G.1X workers (minimum allowed) and a 10-minute timeout.
resource "aws_glue_job" "summary_etl" {
  name              = "${var.project_name}-summary-etl"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.processed.id}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  # Arguments passed into sys.argv inside glue/sales_summary_etl.py
  default_arguments = {
    "--job-language"  = "python"
    "--DATABASE_NAME" = aws_glue_catalog_database.sales_db.name
    "--FINAL_BUCKET"  = aws_s3_bucket.final.id
  }
}

# 4. FINAL CRAWLER: Scans s3://<final-bucket>/summary/ after the ETL job runs so Athena can query the output.
resource "aws_glue_crawler" "final" {
  name          = "${var.project_name}-final-crawler"
  database_name = aws_glue_catalog_database.sales_db.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.final.id}/summary/"
  }
}

# 5. ATHENA WORKGROUP: Pre-configures the S3 query result folder so you never have to click "Manage" manually!
resource "aws_athena_workgroup" "pipeline" {
  name          = "${var.project_name}-workgroup"
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.final.id}/athena-results/"
    }
  }
}
