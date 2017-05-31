#!/usr/bin/env bash

function LOCK_SET(){

    [[ -z "${LOCK_FILE}" ]] && return 1

    exec 100>"${LOCK_FILE}"

    flock -xn 100 || return 1

    #echo $$ 1>&100 || return 1

    echo "LOCK SET AT (${LOCK_FILE}) FOR ($$)"

    return 0

}

function LOCK_UNSET(){

    { >&100; } 2> /dev/null || return 0

    rm "${LOCK_FILE}"

    flock -u 100

    exec 100>&-

    echo "LOCK UNSET AT (${LOCK_FILE})"

    return 0

}

#function LOCK_IS(){
#
#    echo "LOCK CHECK..."
#
#    [[ -z "${LOCK_FILE-}" ]] && echo "LOCK NOT FOUND." && return 1
#
#    [[ ! -f ${LOCK_FILE} ]] && echo "LOCK NOT FOUND." && return 1
#
#    local PID="$(cat "${LOCK_FILE}")"
#
#    [[ -z "${PID}" ]] && echo "LOCK NOT FOUND." && return 1
#
#    #LOCKED and PID IS RUNNING
#    ps --noheaders -p ${PID} &> /dev/null && echo "LOCK WAS FOUND." && return 0
#
#    LOCK_UNSET && echo "LOCK NOT FOUND." && return 1
#
#}