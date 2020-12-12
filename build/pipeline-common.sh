#!/bin/bash

# Common steps for building / testing to be run in each pipeline.
# This is the recommended way of sharing behavior between pipelines as per:
# https://community.atlassian.com/t5/Bitbucket-questions/Pipeline-with-multiple-scripts-runs-only-the-last-one-broken/qaq-p/1239759#M49687

# exit when any command fails
set -e

PACKAGE_PATH="${GOPATH}/src/bandi.com/airflow"
mkdir -pv "${PACKAGE_PATH}"
tar -cO --exclude=bitbucket-pipelines.yml . | tar -x -C "${PACKAGE_PATH}"
cd "${PACKAGE_PATH}"

apk upgrade --update 
apk add --no-cache git curl build-base autoconf automake libtool protobuf protobuf-dev mercurial openssh docker-compose bash jq gmp-dev openssl-dev python3 python3-dev gcc gfortran freetype-dev musl-dev libpng-dev g++ lapack-dev

# apt-get update && apt-get install -y make build-essential git openssl --no-install-recommends

make install-dependencies

# TODO: Document why we need this
ln -s /usr/include /usr/local/include

# Compile Dags and check
make docker-build