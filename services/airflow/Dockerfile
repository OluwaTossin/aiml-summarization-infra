FROM python:3.11-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    AIRFLOW_HOME=/opt/airflow \
    AIRFLOW__CORE__LOAD_EXAMPLES=False \
    AIRFLOW__CORE__DAGS_FOLDER=/opt/airflow/dags \
    AIRFLOW__LOGGING__BASE_LOG_FOLDER=/opt/airflow/logs

# Minimal OS deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates build-essential libpq-dev git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/airflow

# Python deps first (layer caching)
COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install -r requirements.txt

# Runtime dirs
RUN mkdir -p /opt/airflow/dags /opt/airflow/logs

# Bake DAGs and configs
COPY dags/ /opt/airflow/dags/
COPY webserver_config.py /opt/airflow/webserver_config.py
COPY airflow.cfg         /opt/airflow/airflow.cfg

# Prefetch HF model into the image (private subnet friendly)
# Cache will live under /opt/models; we enable offline mode AFTER download.
ENV HF_HOME=/opt/models \
    TRANSFORMERS_CACHE=/opt/models \
    HUGGINGFACE_HUB_CACHE=/opt/models
RUN mkdir -p /opt/models && python - <<'PY'
from transformers import pipeline
# Small, CPU-friendly summarizer. Change if you prefer.
MODEL_ID = "sshleifer/distilbart-cnn-12-6"
p = pipeline("summarization", model=MODEL_ID)
# A tiny warm-up to ensure weights are fully cached in the image
print(p("Airflow image build sanity test.")[0]["summary_text"])
PY
ENV TRANSFORMERS_OFFLINE=1

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
CMD ["/entrypoint.sh"]
