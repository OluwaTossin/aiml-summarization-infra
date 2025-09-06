# services/airflow/dags/03_audit_compact_dag.py
from __future__ import annotations
import os, io, gzip, json
from datetime import datetime, timezone
from typing import List

import boto3
from airflow.decorators import dag, task
from airflow.utils.dates import days_ago

PROCESSED_BUCKET = os.getenv("PROCESSED_BUCKET", "your-processed-bucket")
PROCESSED_PREFIX = os.getenv("S3_OUTPUT_PREFIX", "processed/")
COMPACT_PREFIX   = os.getenv("COMPACT_PREFIX", "compact/")
MAX_FILES        = int(os.getenv("COMPACT_MAX_FILES", "5000"))  # safety guard

def s3():
    return boto3.client("s3")

@dag(
    dag_id="03_audit_compact_dag",
    description="Audit processed outputs and create a compact gz file per run/day.",
    schedule="@daily",
    start_date=days_ago(1),
    catchup=False,
    tags=["phase2", "audit", "compact"],
    default_args={"owner": "airflow"},
)
def audit_and_compact():
    @task
    def list_processed() -> List[str]:
        keys: List[str] = []
        cli = s3()
        continuation = None
        while True:
            kwargs = dict(Bucket=PROCESSED_BUCKET, Prefix=PROCESSED_PREFIX, MaxKeys=1000)
            if continuation:
                kwargs["ContinuationToken"] = continuation
            resp = cli.list_objects_v2(**kwargs)
            for obj in resp.get("Contents", []):
                if obj["Size"] > 0 and obj["Key"].endswith(".txt"):
                    keys.append(obj["Key"])
                    if len(keys) >= MAX_FILES:
                        return keys
            if resp.get("IsTruncated"):
                continuation = resp.get("NextContinuationToken")
            else:
                break
        return keys

    @task
    def write_audit_and_compact(keys: List[str]) -> str:
        cli = s3()
        now = datetime.now(timezone.utc)
        datestr = now.strftime("%Y%m%d")
        # Build compact content
        buffer = io.BytesIO()
        with gzip.GzipFile(fileobj=buffer, mode="wb") as gz:
            for k in keys:
                body = cli.get_object(Bucket=PROCESSED_BUCKET, Key=k)["Body"].read()
                gz.write(body)
                gz.write(b"\n")
        comp_key = f"{COMPACT_PREFIX.rstrip('/')}/summaries_{datestr}.txt.gz"
        cli.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=comp_key,
            Body=buffer.getvalue(),
            ContentType="application/gzip",
            Metadata={"files_compacted": str(len(keys)), "generated_at": now.isoformat()},
        )
        # Audit manifest
        audit_key = f"{PROCESSED_PREFIX.rstrip('/')}/_audit/manifest_{datestr}.json"
        cli.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=audit_key,
            Body=json.dumps({"date": datestr, "count": len(keys), "compact_key": comp_key, "files": keys}).encode("utf-8"),
            ContentType="application/json",
        )
        return f"s3://{PROCESSED_BUCKET}/{comp_key}"

    keys = list_processed()
    write_audit_and_compact(keys)

dag = audit_and_compact()
