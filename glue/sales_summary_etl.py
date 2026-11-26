import sys
import boto3
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "DATABASE_NAME", "FINAL_BUCKET"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Automatically find the processed table created by the crawler in csv_sales_db
glue_client = boto3.client("glue")
tables = glue_client.get_tables(DatabaseName=args["DATABASE_NAME"])["TableList"]
processed_tables = [t["Name"] for t in tables if t["Name"] != "summary"]
if not processed_tables:
    raise RuntimeError(f"No processed table found in database {args['DATABASE_NAME']}")
table_name = processed_tables[0]
print(f"Reading from Glue Catalog table: {args['DATABASE_NAME']}.{table_name}")

# 1. Read cleaned data from AWS Glue Data Catalog
dynamic_frame = glueContext.create_dynamic_frame.from_catalog(
    database=args["DATABASE_NAME"],
    table_name=table_name
)

df = dynamic_frame.toDF()

# 2. Group by category and calculate sum(amount) and count(order_id)
summary_df = (
    df.groupBy("category")
      .agg(
          F.round(F.sum(F.col("amount").cast("double")), 2).alias("total_amount"),
          F.count("order_id").alias("order_count")
      )
      .orderBy(F.desc("total_amount"))
)

# 3. Write final aggregated CSV to the final S3 bucket
output_path = f"s3://{args['FINAL_BUCKET']}/summary/"
summary_df.coalesce(1).write.mode("overwrite").option("header", "true").csv(output_path)

job.commit()
