#!/usr/bin/env bash

set -euo pipefail

function verify_db_connection {
    DB_URL="${1}"

    DB_CHECK_MAX_COUNT=${MAX_DB_CHECK_COUNT:=20}
    DB_CHECK_SLEEP_TIME=${DB_CHECK_SLEEP_TIME:=3}

    local DETECTED_DB_BACKEND=""
    local DETECTED_DB_HOST=""
    local DETECTED_DB_PORT=""


    if [[ ${DB_URL} != sqlite* ]]; then
        # Auto-detect DB parameters
        [[ ${DB_URL} =~ ([^:]*)://([^@/]*)@?([^/:]*):?([0-9]*)/([^\?]*)\??(.*) ]] && \
            DETECTED_DB_BACKEND=${BASH_REMATCH[1]} &&
            # Not used USER match
            DETECTED_DB_HOST=${BASH_REMATCH[3]} &&
            DETECTED_DB_PORT=${BASH_REMATCH[4]} &&
            # Not used SCHEMA match
            # Not used PARAMS match

        echo DB_BACKEND="${DB_BACKEND:=${DETECTED_DB_BACKEND}}"

        if [[ -z "${DETECTED_DB_PORT=}" ]]; then
            if [[ ${DB_BACKEND} == "postgres"* ]]; then
                DETECTED_DB_PORT=5432
            elif [[ ${DB_BACKEND} == "mysql"* ]]; then
                DETECTED_DB_PORT=3306
            fi
        fi

        DETECTED_DB_HOST=${DETECTED_DB_HOST:="localhost"}

        # Allow the DB parameters to be overridden by environment variable
        echo DB_HOST="${DB_HOST:=${DETECTED_DB_HOST}}"
        echo DB_PORT="${DB_PORT:=${DETECTED_DB_PORT}}"

        while true
        do
            set +e
            LAST_CHECK_RESULT=$(nc -zvv "${DB_HOST}" "${DB_PORT}" >/dev/null 2>&1)
            RES=$?
            set -e
            if [[ ${RES} == 0 ]]; then
                echo
                break
            else
                echo -n "."
                DB_CHECK_MAX_COUNT=$((DB_CHECK_MAX_COUNT-1))
            fi
            if [[ ${DB_CHECK_MAX_COUNT} == 0 ]]; then
                echo
                echo "ERROR! Maximum number of retries (${DB_CHECK_MAX_COUNT}) reached while checking ${DB_BACKEND} db. Exiting"
                echo
                break
            else
                sleep "${DB_CHECK_SLEEP_TIME}"
            fi
        done
        if [[ ${RES} != 0 ]]; then
            echo "        ERROR: ${DB_URL} db could not be reached!"
            echo
            echo "${LAST_CHECK_RESULT}"
            echo
            export EXIT_CODE=${RES}
        fi
    fi
}