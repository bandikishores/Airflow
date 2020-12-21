# README #

This Repo contains the Code for Airflow Service Docker and its Dags, Plugins. <br/>
This Airflow outputs all logs to console apart from file, so if there are any kubernetes log scrapper they'll get the logs. <br/>

## How to use it ##

### To start the Service using docker-compose ###
* make docker-build
* docker-compose up
* To check if the task command has been run, check for "Running command: " (For Bash task) or "cmd:" (For Spark-submit task) in logs

### Setting up using local kubernetes ###

* kubectl create namespace workflow
* kubectl apply -f /Users/bandi/go/src/bandi.com/Airflow/kube-helm-files/blitz-variables.yml --namespace=workflow 
* kubectl apply -f /Users/bandi/go/src/bandi.com/Airflow/kube-helm-files/role.yml --namespace=workflow 
* helm uninstall --create-namespace --namespace workflow workflow-webserver
* helm install workflow-service --namespace workflow --values /Users/bandi/go/src/bandi.com/Airflow/kube-helm-files/values.yaml --debug .
* export POD_NAME=$(kubectl get pods --namespace workflow -l "component=web,app=workflow" -o jsonpath="{.items[0].metadata.name}") && kubectl logs -f $POD_NAME --namespace workflow
* export POD_NAME=$(kubectl get pods --namespace workflow -l "component=web,app=workflow" -o jsonpath="{.items[0].metadata.name}") && kubectl port-forward --namespace workflow $POD_NAME 8080:8080
* export POD_NAME=$(kubectl get pods --namespace workflow -l "component=scheduler,app=workflow" -o jsonpath="{.items[0].metadata.name}") && kubectl exec -it $POD_NAME --namespace workflow /bin/bash

### Setting up Sequential Executor ###
* docker run --rm -it -p 8080:8080 -p 8793:8793 -p 5555:5555 -e AIRFLOW__CORE__FERNET_KEY=vXWc3rYSF1RlUP9PjmccHFAeRn-Zj8SD9Xf5A8rIhVY= -e AIRFLOW__CORE__EXECUTOR=SequentialExecutor bandi-docker.jfrog.io/workflow-service:v0.1.dev- webserver

### Generating a new Fernet Key ###
* python fernet_generator.py
