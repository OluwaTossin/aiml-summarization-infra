# services/airflow/dags/01_ingest_preprocess_dag.py
from __future__ import annotations
import os, re, json
from datetime import datetime
from typing import List, Dict

import boto3
from airflow.decorators import dag, task
from airflow.utils.dates import days_ago

# ---- Configuration via env ----
RAW_BUCKET         = os.getenv("RAW_BUCKET", "your-raw-bucket")
S3_INPUT_PREFIX    = os.getenv("S3_INPUT_PREFIX", "raw/")
PREPROC_BUCKET     = os.getenv("PREPROC_BUCKET", os.getenv("PROCESSED_BUCKET", "your-processed-bucket"))
PREPROC_PREFIX     = os.getenv("PREPROC_PREFIX", "preprocessed/")
MAX_CHARS          = int(os.getenv("MAX_PREPROC_CHARS", "8000"))

def s3():
    return boto3.client("s3")

@dag(
    dag_id="01_ingest_preprocess_dag",
    description="Ingest raw text from S3, normalize, and write to preprocessed/",
    schedule="@hourly",
    start_date=days_ago(1),
    catchup=False,
    tags=["phase2", "s3", "preprocess"],
    default_args={"owner": "airflow"},
)
def ingest_preprocess():
    @task
    def list_raw_keys() -> List[str]:
        keys: List[str] = []
        cli = s3()
        continuation = None
        while True:
            kwargs = dict(Bucket=RAW_BUCKET, Prefix=S3_INPUT_PREFIX, MaxKeys=1000)
            if continuation:
                kwargs["ContinuationToken"] = continuation
            resp = cli.list_objects_v2(**kwargs)
            for obj in resp.get("Contents", []):
                if obj["Size"] > 0 and obj["Key"].endswith(".txt"):
                    keys.append(obj["Key"])
            if resp.get("IsTruncated"):
                continuation = resp.get("NextContinuationToken")
            else:
                break
        return keys

    @task
    def preprocess(key: str) -> Dict:
        cli = s3()
        body = cli.get_object(Bucket=RAW_BUCKET, Key=key)["Body"].read().decode("utf-8", errors="ignore")
        text = re.sub(r"\s+", " ", body).strip()
        text = text[:MAX_CHARS]
        out_key = key.replace(S3_INPUT_PREFIX, PREPROC_PREFIX, 1)
        cli.put_object(
            Bucket=PREPROC_BUCKET,
            Key=out_key,
            Body=text.encode("utf-8"),
            ContentType="text/plain",
            Metadata={"source_bucket": RAW_BUCKET, "source_key": key, "processed_at": datetime.utcnow().isoformat()},
        )
        return {"in_key": key, "out_key": out_key}

    @task
    def report(results: List[Dict]) -> str:
        # write a tiny audit stub for this run
        cli = s3()
        stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        audit_key = f"{PREPROC_PREFIX.rstrip('/')}/_audit/ingest_preprocess_{stamp}.json"
        cli.put_object(
            Bucket=PREPROC_BUCKET,
            Key=audit_key,
            Body=json.dumps({"count": len(results), "items": results}) .encode("utf-8"),
            ContentType="application/json",
        )
        return f"s3://{PREPROC_BUCKET}/{audit_key}"

    keys = list_raw_keys()
    outputs = preprocess.expand(key=keys)
    report(outputs)

dag = ingest_preprocess()
