# services/airflow/dags/02_summarize_dag.py
from __future__ import annotations
import os, json
from datetime import datetime
from typing import List, Dict

import boto3
from airflow.decorators import dag, task
from airflow.utils.dates import days_ago

# ---- Configuration via env ----
PREPROC_BUCKET     = os.getenv("PREPROC_BUCKET", os.getenv("PROCESSED_BUCKET", "your-processed-bucket"))
PREPROC_PREFIX     = os.getenv("PREPROC_PREFIX", "preprocessed/")
PROCESSED_BUCKET   = os.getenv("PROCESSED_BUCKET", "your-processed-bucket")
PROCESSED_PREFIX   = os.getenv("S3_OUTPUT_PREFIX", "processed/")
HF_MODEL_PATH      = os.getenv("HF_MODEL_PATH", "/opt/models/sshleifer/distilbart-cnn-12-6")
SUM_MAX_LEN        = int(os.getenv("SUM_MAX_LEN", "128"))
SUM_MIN_LEN        = int(os.getenv("SUM_MIN_LEN", "30"))

def s3():
    return boto3.client("s3")

@dag(
    dag_id="02_summarize_dag",
    description="Summarize preprocessed texts and store to processed/",
    schedule="@hourly",
    start_date=days_ago(1),
    catchup=False,
    tags=["phase2", "summarization", "s3"],
    default_args={"owner": "airflow"},
)
def summarize():
    @task
    def list_preprocessed() -> List[str]:
        keys: List[str] = []
        cli = s3()
        continuation = None
        while True:
            kwargs = dict(Bucket=PREPROC_BUCKET, Prefix=PREPROC_PREFIX, MaxKeys=1000)
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
    def summarize_key(key: str) -> Dict:
        from transformers import pipeline  # imported inside task to keep worker import light
        summarizer = pipeline("summarization", model=HF_MODEL_PATH)
        cli = s3()
        text = cli.get_object(Bucket=PREPROC_BUCKET, Key=key)["Body"].read().decode("utf-8", errors="ignore")
        summary = summarizer(text, max_length=SUM_MAX_LEN, min_length=SUM_MIN_LEN, do_sample=False)[0]["summary_text"]
        out_key = key.replace(PREPROC_PREFIX, PROCESSED_PREFIX, 1)
        cli.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=out_key,
            Body=summary.encode("utf-8"),
            ContentType="text/plain",
            Metadata={"source_bucket": PREPROC_BUCKET, "source_key": key, "summarized_at": datetime.utcnow().isoformat()},
        )
        return {"in_key": key, "out_key": out_key}

    @task
    def report(results: List[Dict]) -> str:
        cli = s3()
        stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        audit_key = f"{PROCESSED_PREFIX.rstrip('/')}/_audit/summarize_{stamp}.json"
        cli.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=audit_key,
            Body=json.dumps({"count": len(results), "items": results}).encode("utf-8"),
            ContentType="application/json",
        )
        return f"s3://{PROCESSED_BUCKET}/{audit_key}"

    keys = list_preprocessed()
    outputs = summarize_key.expand(key=keys)
    report(outputs)

dag = summarize()
