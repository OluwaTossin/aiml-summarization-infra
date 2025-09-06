#!/usr/bin/env bash
set -euo pipefail

export AIRFLOW_HOME=${AIRFLOW_HOME:-/opt/airflow}
export AIRFLOW__CORE__DAGS_FOLDER=${AIRFLOW__CORE__DAGS_FOLDER:-/opt/airflow/dags}
export AIRFLOW__LOGGING__BASE_LOG_FOLDER=${AIRFLOW__LOGGING__BASE_LOG_FOLDER:-/opt/airflow/logs}
export AIRFLOW__CORE__LOAD_EXAMPLES=${AIRFLOW__CORE__LOAD_EXAMPLES:-False}

# Ensure runtime dirs exist (covers the case when a fresh named volume is mounted)
mkdir -p "$AIRFLOW_HOME" "$AIRFLOW__CORE__DAGS_FOLDER" "$AIRFLOW__LOGGING__BASE_LOG_FOLDER"

# Initialize metadata DB (SQLite for demo)
airflow db init

# Admin user (from env or defaults)
ADMIN_USER="${AIRFLOW_ADMIN_USER:-admin}"
ADMIN_PWD="${AIRFLOW_ADMIN_PWD:-admin}"
ADMIN_EMAIL="${AIRFLOW_ADMIN_EMAIL:-admin@example.com}"

airflow users create \
  --username "$ADMIN_USER" \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email "$ADMIN_EMAIL" \
  --password "$ADMIN_PWD" || true

# Start scheduler in background; webserver in foreground on 0.0.0.0:8080
airflow scheduler &
exec airflow webserver --port 8080 --hostname 0.0.0.0
