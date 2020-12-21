# Workflow-Service Helm Chart

## Usage

### 1 - Install & Provision a Postgres DB
```
CREATE USER airflow;
CREATE DATABASE airflow;
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
alter user airflow password 'airflow';
```

### 2 - Configure Kubernetes & Config
* Create namespace
    `kubectl create -f ./namespace.yaml`
* Create a Service Account for Workflow 
``` 
 kubectl apply -f /Users/bandi/go/src/bandi.com/Airflow/kube-helm-files/role.yml --namespace=workflow 
```
* Change values inside blitz-values.yml

### 3 - Configure Kubernetes & Config




TODO:// Verify the values files here