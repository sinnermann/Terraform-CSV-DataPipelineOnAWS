import csv
import io
import os
import urllib.parse
import boto3

# Initialize the AWS S3 client and read the destination bucket name from Lambda Environment Variables
s3 = boto3.client("s3")
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]

def lambda_handler(event, context):
    # Loop through every S3 upload event that triggered this Lambda invocation
    for record in event["Records"]:
        source_bucket = record["s3"]["bucket"]["name"]
        source_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        # 1. Download and decode the raw CSV file from the Raw S3 bucket
        response = s3.get_object(Bucket=source_bucket, Key=source_key)
        raw_text = response["Body"].read().decode("utf-8")

        # 2. Set up CSV reader (input) and in-memory CSV writer (output)
        reader = csv.DictReader(io.StringIO(raw_text))
        output = io.StringIO()
        fieldnames = ["order_id", "customer_name", "category", "amount", "status"]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()

        cleaned_count = 0
        for row in reader:
            status = (row.get("status") or "").strip().lower()
            amount_str = (row.get("amount") or "").strip()

            # 3. Validation rule: Skip cancelled orders or rows missing an order amount
            if status != "completed" or not amount_str:
                continue

            try:
                amount = round(float(amount_str), 2)
            except ValueError:
                continue

            # 4. Standardization rules: Collapse extra spaces, apply Title Case, and label blank categories
            customer_name = " ".join((row.get("customer_name") or "").split()).title()
            category = (row.get("category") or "").strip() or "Uncategorized"

            writer.writerow({
                "order_id": (row.get("order_id") or "").strip(),
                "customer_name": customer_name,
                "category": category,
                "amount": amount,
                "status": "completed"
            })
            cleaned_count += 1

        # 5. Upload the cleaned CSV file to the Processed S3 bucket
        clean_key = f"cleaned_{os.path.basename(source_key)}"
        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=clean_key,
            Body=output.getvalue(),
            ContentType="text/csv"
        )
        print(f"Processed {cleaned_count} valid rows -> s3://{PROCESSED_BUCKET}/{clean_key}")

    return {"statusCode": 200, "body": "CSV cleaned successfully"}
