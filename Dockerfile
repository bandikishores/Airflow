ARG AIRFLOW_VERSION="2.0.0rc1"
ARG AIRFLOW_INSTALL_VERSION="==${AIRFLOW_VERSION}"
ARG PYTHON_MAJOR_MINOR_VERSION="3.8"

# Reference - https://airflow.apache.org/docs/apache-airflow/stable/production-deployment.html
From apache/airflow:${AIRFLOW_VERSION}-python${PYTHON_MAJOR_MINOR_VERSION}

ARG AIRFLOW_VERSION=${AIRFLOW_VERSION}
ARG AIRFLOW_INSTALL_VERSION="==${AIRFLOW_VERSION}"
ARG PYTHON_MAJOR_MINOR_VERSION=${PYTHON_MAJOR_MINOR_VERSION}
ARG ADDITIONAL_AIRFLOW_EXTRAS="crypto,async,amazon,celery,kubernetes,spark,apache.spark,apache.livy,cncf.kubernetes,docker,dask,aws,s3,elasticsearch,ftp,grpc,hashicorp,http,google,microsoft.azure,mysql,postgres,redis,sendgrid,sftp,slack,ssh,statsd,virtualenv"
ARG ADDITIONAL_PYTHON_DEPS=""
ARG ADDITIONAL_RUNTIME_APT_DEPS="default-jre-headless"
ARG CONSTRAINT_REQUIREMENTS="/tmp/constraints.txt"

USER root

# Install basic and additional apt dependencies
RUN mkdir -pv /usr/share/man/man1 \
    && mkdir -pv /usr/share/man/man7 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
           apt-transport-https \
           apt-utils \
           build-essential \
           ca-certificates \
           curl \
           gnupg \
           dirmngr \
           freetds-bin \
           freetds-dev \
           gosu \
           krb5-user \
           ldap-utils \
           libffi-dev \
           libkrb5-dev \
           libpq-dev \
           libsasl2-2 \
           libsasl2-dev \
           libsasl2-modules \
           libssl-dev \
           locales  \
           lsb-release \
           nodejs \
           openssh-client \
           postgresql-client \
           rsync \
           netcat \
           sasl2-bin \
           software-properties-common \
           sqlite3 \
           sudo \
           unixodbc \
           unixodbc-dev \
           yarn \
           default-jre-headless \
           wget \
           python3-pip \
           mysql-client \
           libmysqlclient-dev \
           python3-dev \
    && apt-get update -yqq \
    && apt-get install -y git procps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY config/constraints.txt /tmp/constraints.txt
RUN pip3 install --user -U apache-airflow[${ADDITIONAL_AIRFLOW_EXTRAS}]==${AIRFLOW_VERSION} --constraint /tmp/constraints.txt && \
    find /root/.local/ -name '*.pyc' -print0 | xargs -0 rm -r && \
    find /root/.local/ -type d -name '__pycache__' -print0 | xargs -0 rm -r && \
    find /root/.local -executable -print0 | xargs --null chmod g+x && \
    find /root/.local -print0 | xargs --null chmod g+rw

COPY --chown=airflow:root airflow-data/ ${AIRFLOW_HOME}/
COPY scripts/* ${AIRFLOW_HOME}/scripts/
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

# Workaround for logging to console - https://github.com/astronomer/airflow-guides/blob/main/guides/logging.md
ARG AIRFLOW_SITE_PACKAGE="/root/.local/lib/python${PYTHON_MAJOR_MINOR_VERSION}/site-packages/airflow"
COPY --chown=airflow:root config/logging_config.py ${AIRFLOW_SITE_PACKAGE}/config_templates/airflow_local_settings.py
COPY --chown=airflow:root config/logging_config.py /usr/local/lib/python${PYTHON_MAJOR_MINOR_VERSION}/dist-packages/airflow/config_templates/airflow_local_settings.py

# This is to fix - https://stackoverflow.com/questions/54141416/airflow-neither-sqlalchemy-database-uri-nor-sqlalchemy-binds-is-set
COPY config/webserver_config.py ${AIRFLOW_HOME}/webserver_config.py

RUN mkdir -pv "${AIRFLOW_HOME}"; \
    mkdir -pv "${AIRFLOW_HOME}/dags"; \
    mkdir -pv "${AIRFLOW_HOME}/logs"; \
    mkdir -pv "${AIRFLOW_HOME}/plugins"; 

RUN chmod a+x /clean-logs && \
    chmod g=u /etc/passwd && \
    chmod 777 ${AIRFLOW_HOME}/scripts/*

RUN chown -R "airflow:root" "${AIRFLOW_HOME}"; \
    find "${AIRFLOW_HOME}" -executable -print0 | xargs --null chmod g+x && \
    find "${AIRFLOW_HOME}" -print0 | xargs --null chmod g+rw

# Compile Dags to see if they're valid. Reset Alchemy conn after verification of dags
ENV AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres:5432/airflow
ENV AIRFLOW__CORE__LOGGING_LEVEL="INFO"
ENV AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION="False"
RUN mkdir -p /opt/airflow/logs/scheduler/ 
RUN python3 -m compileall -f ${AIRFLOW_HOME}/dags/
ENV AIRFLOW__CORE__SQL_ALCHEMY_CONN=
ENV AIRFLOW__SCHEDULER__CHILD_PROCESS_LOG_DIRECTORY="${AIRFLOW_HOME}/logs"
ENV AIRFLOW__KUBERNETES__DAGS_IN_IMAGE="True"
ENV PATH="${AIRFLOW_HOME}/.local/bin:~/.local/bin:${PATH}"
# This is needed to avoid No module named 'airflow_logging_settings' when loading settings.py
ENV PYTHONPATH="${AIRFLOW_SITE_PACKAGE}/config_templates:${PYTHONPATH}"
ENV AIRFLOW_USER_HOME_DIR=${AIRFLOW_HOME}

WORKDIR ${AIRFLOW_HOME}

ENTRYPOINT ["./scripts/entrypoint.sh"]
CMD ["airflow", "--help"]
