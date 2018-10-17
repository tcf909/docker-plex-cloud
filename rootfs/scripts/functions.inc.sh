#!/usr/bin/env bash
[[ "${DEBUG}" == "true" ]] && set -x

FIRST_RUN_FILE="/.firstRun"

[[ -e ${FIRST_RUN_FILE} ]] && FIRST_RUN=true || FIRST_RUN=false

function dnsToIp {

    [[ -z "${1}" ]] && return 1

    unset dnsToIpResult

    dnsToIpResult=()

    IFS=',' read -ra ENTRIES <<< "${1}"

    for ENTRY in "${ENTRIES[@]}"; do

        if [[ ${ENTRY} =~ (https?://)([^:]+)(:[0-9]+)? ]]; then

            PROTOCOL="${BASH_REMATCH[1]}"
            ADDRESS="${BASH_REMATCH[2]}"
            PORT="${BASH_REMATCH[3]}"
            IPS="$(getent ahosts ${ADDRESS} | grep RAW | awk '{print $1}')"

            for IP in $IPS; do

                dnsToIpResult+=("${PROTOCOL}${IP}${PORT}")

            done

        fi

    done

}