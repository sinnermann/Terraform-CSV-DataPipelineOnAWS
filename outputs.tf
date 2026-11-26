# Prints the exact generated S3 bucket names and Athena Workgroup name in the terminal after "terraform apply".
output "raw_bucket_name" {
  description = "Name of the Raw S3 bucket where you upload sales_raw.csv"
  value       = aws_s3_bucket.raw.id
}

output "processed_bucket_name" {
  description = "Name of the Processed S3 bucket where Lambda writes cleaned CSVs"
  value       = aws_s3_bucket.processed.id
}

output "final_bucket_name" {
  description = "Name of the Final S3 bucket where Glue writes aggregated summary CSVs"
  value       = aws_s3_bucket.final.id
}

output "athena_workgroup" {
  description = "Pre-configured Amazon Athena Workgroup name"
  value       = aws_athena_workgroup.pipeline.name
}
