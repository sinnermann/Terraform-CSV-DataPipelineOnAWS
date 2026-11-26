import time
import subprocess
import boto3

# 1. Read exact bucket names & workgroup directly from Terraform outputs!
raw_bucket = subprocess.check_output(["terraform", "output", "-raw", "raw_bucket_name"], text=True).strip()
final_bucket = subprocess.check_output(["terraform", "output", "-raw", "final_bucket_name"], text=True).strip()
workgroup = subprocess.check_output(["terraform", "output", "-raw", "athena_workgroup"], text=True).strip()

s3 = boto3.client("s3", region_name="us-east-1")
glue = boto3.client("glue", region_name="us-east-1")
athena = boto3.client("athena", region_name="us-east-1")

def wait_for_crawler(crawler_name):
    print(f"Starting crawler: {crawler_name}...")
    glue.start_crawler(Name=crawler_name)
    while True:
        state = glue.get_crawler(Name=crawler_name)["Crawler"]["State"]
        if state == "READY":
            print(f"Crawler {crawler_name} finished!")
            break
        time.sleep(10)

# Step A: Upload sales_raw.csv to Raw S3 bucket (triggers Lambda automatically)
print(f"Uploading data/sales_raw.csv to s3://{raw_bucket}/sales_raw.csv...")
s3.upload_file("data/sales_raw.csv", raw_bucket, "sales_raw.csv")
time.sleep(5)  # Give Lambda 5 seconds to write cleaned_sales_raw.csv

# Step B: Run Processed Crawler
wait_for_crawler("csv-pipeline-processed-crawler")

# Step C: Run Glue ETL Job
print("Starting Glue ETL job: csv-pipeline-summary-etl...")
job_run_id = glue.start_job_run(JobName="csv-pipeline-summary-etl")["JobRunId"]
while True:
    status = glue.get_job_run(JobName="csv-pipeline-summary-etl", RunId=job_run_id)["JobRun"]["JobRunState"]
    if status in ["SUCCEEDED", "FAILED", "STOPPED", "TIMEOUT"]:
        print(f"Glue ETL job finished with status: {status}")
        if status != "SUCCEEDED":
            raise RuntimeError(f"Glue job failed: {status}")
        break
    time.sleep(15)

# Step D: Run Final Crawler
wait_for_crawler("csv-pipeline-final-crawler")

# Step E: Run Athena SQL Query and print the results right in VS Code!
print("\nRunning Athena SQL verification query...")
query_id = athena.start_query_execution(
    QueryString='SELECT * FROM "csv_sales_db"."summary" ORDER BY total_amount DESC;',
    WorkGroup=workgroup
)["QueryExecutionId"]

while True:
    state = athena.get_query_execution(QueryExecutionId=query_id)["QueryExecution"]["Status"]["State"]
    if state in ["SUCCEEDED", "FAILED", "CANCELLED"]:
        break
    time.sleep(2)

results = athena.get_query_results(QueryExecutionId=query_id)
print("\n=== ATHENA FINAL RESULTS ===")
for row in results["ResultSet"]["Rows"]:
    print(" | ".join(col.get("VarCharValue", "") for col in row["Data"]))
