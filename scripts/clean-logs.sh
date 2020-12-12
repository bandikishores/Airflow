#!/usr/bin/env bash
set -euo pipefail

DIRECTORY="${AIRFLOW_HOME:-/opt/airflow}"
RETENTION="${AIRFLOW__LOG_RETENTION_DAYS:-15}"

trap "exit" INT TERM

EVERY=$((15*60))

echo "Cleaning logs every $EVERY seconds"

while true; do
  echo "Trimming airflow logs to ${RETENTION} days."
  find "${DIRECTORY}"/logs -mtime +"${RETENTION}" -name '*.log' -delete

  seconds=$(( $(date -u +%s) % EVERY))
  [[ $seconds -lt 1 ]] || sleep $((EVERY - seconds))
done
