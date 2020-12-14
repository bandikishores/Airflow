#!/usr/bin/env bash

set -euo pipefail

# Global defaults 
: "${AIRFLOW__CORE__FERNET_KEY:=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}}"
: "${AIRFLOW_HOME:=${AIRFLOW_HOME:-/opt/airflow}}"
: "${AIRFLOW__CORE__EXECUTOR:=${EXECUTOR:-Kubernetes}Executor}"
: "${AIRFLOW__CORE__LOAD_EXAMPLES:=${AIRFLOW__CORE__LOAD_EXAMPLES:-False}}"
: "${AIRFLOW__WEBSERVER__RBAC:=${AIRFLOW__WEBSERVER__RBAC:-False}}"
: "${AIRFLOW__KUBERNETES__DAGS_IN_IMAGE:=${AIRFLOW__KUBERNETES__DAGS_IN_IMAGE:-True}}"
: "${AIRFLOW__API__AUTH_BACKEND:=${AIRFLOW__API__AUTH_BACKEND:-airflow.api.auth.backend.default}}"
# if no DB configured - use sqlite db by default
: "${AIRFLOW__CORE__SQL_ALCHEMY_CONN:=${AIRFLOW__CORE__SQL_ALCHEMY_CONN:="sqlite:///${AIRFLOW_HOME}/airflow.db"}}"

export \
  AIRFLOW_HOME \
  AIRFLOW__CORE__EXECUTOR \
  AIRFLOW__CORE__FERNET_KEY \
  AIRFLOW__CORE__LOAD_EXAMPLES \
  AIRFLOW__WEBSERVER__RBAC \
  AIRFLOW__API__AUTH_BACKEND \
  AIRFLOW__KUBERNETES__DAGS_IN_IMAGE \
  AIRFLOW__CORE__SQL_ALCHEMY_CONN \

source ./scripts/verify_db_connection.sh

verify_db_connection "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}"

if ! whoami &> /dev/null; then
  if [[ -w /etc/passwd ]]; then
    echo "${USER_NAME:-default}:x:$(id -u):0:${USER_NAME:-default} user:${AIRFLOW_USER_HOME_DIR}:/sbin/nologin" \
        >> /etc/passwd
  fi
  export HOME="${AIRFLOW_USER_HOME_DIR}"
fi

# Warning: command environment variables (*_CMD) have priority over usual configuration variables
# for configuration parameters that require sensitive information. This is the case for the SQL database
# and the broker backend in this entrypoint script.

if [[ -n "${AIRFLOW__CORE__SQL_ALCHEMY_CONN_CMD=}" ]]; then
  verify_db_connection "$(eval "$AIRFLOW__CORE__SQL_ALCHEMY_CONN_CMD")"
else
  # if no DB configured - use sqlite db by default
  AIRFLOW__CORE__SQL_ALCHEMY_CONN="${AIRFLOW__CORE__SQL_ALCHEMY_CONN:="sqlite:///${AIRFLOW_HOME}/airflow.db"}"
  verify_db_connection "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}"
fi

# Note: the broker backend configuration concerns only a subset of Airflow components
if [[ $1 =~ ^(scheduler|celery|worker|flower)$ ]]; then
    if [[ -n "${AIRFLOW__CELERY__BROKER_URL_CMD=}" ]]; then
        verify_db_connection "$(eval "$AIRFLOW__CELERY__BROKER_URL_CMD")"
    else
        AIRFLOW__CELERY__BROKER_URL=${AIRFLOW__CELERY__BROKER_URL:=}
        if [[ -n ${AIRFLOW__CELERY__BROKER_URL=} ]]; then
            verify_db_connection "${AIRFLOW__CELERY__BROKER_URL}"
        fi
    fi
fi

case "$1" in
  webserver)
    # Give the scheduler time to run initdb.
    sleep 20
    if [ "$AIRFLOW__CORE__EXECUTOR" = "LocalExecutor" ] || [ "$AIRFLOW__CORE__EXECUTOR" = "SequentialExecutor" ]; then
      # With the "Local" and "Sequential" executors it should all run in one container.
      airflow scheduler &
    fi
    echo "Starting Web Server"
    airflow webserver
    ;;
  scheduler)
    echo "Initializing DB"
    airflow db init
    if [ "$WORKFLOW_UPGRADE_DB" = "True" ]; then
      echo "Upgrading DB"
      airflow db upgrade
    fi
    echo "Creating Admin User"
    airflow users create --role Admin --username admin --email kishore.bandi@skyflow.com --firstname Workflow --lastname Service --password admin 
    echo "Starting Scheduler"
    exec airflow "$@"
    ;;
  worker)
    # Give the scheduler time to run initdb.
    sleep 20
    echo "Starting Worker"
    exec airflow "$@"
    ;;
  flower)
    sleep 20
    echo "Starting Flower"
    exec airflow "$@"
    ;;
  celery)
    sleep 20
    if [ "$2" = "worker" ]; then
      echo "Starting Celery Worker"
    elif [ "$2" = "flower" ]; then
      echo "Starting Celery Flower"
    fi
    exec airflow "$@"
    ;;
  version)
    echo "Printing Version"
    exec airflow "$@"
    ;;
  bash)
    echo "Executing Bash"
    exec "/bin/bash" "$@"
    ;;
  python)
    echo "Executing Python"
    exec "python" "$@"
    ;;
  *)
    # The command is something like bash, not an airflow subcommand. Just run it in the right environment.
    echo "Executing Command Sent"
    exec "$@"
    ;;
esac
