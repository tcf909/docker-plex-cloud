#!/usr/bin/env bash

#PROVIDES:
# QUEUE_SHIFT, QUEUE_UNSHIFT, QUEUE_PUSH, QUEUE_PUSH_MANY, QUEUE_PUSH_FAIL, QUEUE_READ
#USES:
# QUEUE, QITEM

function QUEUE_SHIFT(){

    QUEUE_READ || return 1

    [[ -z "${QUEUE[@]-}" ]] && return 1

    QITEM="${QUEUE[0]}"

    QUEUE=("${QUEUE[@]:1}")

    QUEUE_SAVE

}

function QUEUE_UNSHIFT(){

    [[ -z "${QITEM-}" ]] && return 1

    QUEUE_READ || return 1

    if [[ -n "${QUEUE[@]-}" ]]; then
        QUEUE=("${QITEM}" "${QUEUE[@]}")
    else
        QUEUE=("${QITEM}")
    fi

    QUEUE_SAVE || return 1

}

function QUEUE_PUSH(){

    [[ -z "${QITEM-}" ]] && return 1

    QUEUE_READ

    QUEUE+=("${QITEM}")

    QUEUE_SAVE || return 1

}

function QUEUE_PUSH_MANY(){

    [[ -z "${QITEM[@]-}" ]] && return 1

    declare -p | grep -e '^declare -[Aa] QITEM=' &> /dev/null || return 1

    QUEUE_READ

    if [[ -n "${QUEUE[@]-}" ]]; then
        QUEUE=("${QUEUE[@]}" "${QITEM[@]}")
    else
        QUEUE=("${QITEM[@]}")
    fi

    QUEUE_SAVE || return 1

}

function QUEUE_PUSH_FAIL(){

    QUEUE_FILE="${QUEUE_FILE_FAILED}"

    QUEUE_PUSH

    local RETURN=$?

    QUEUE_FILE="${QUEUE_FILE_ORIG}"

    return "${RETURN}"

}

function QUEUE_APPEND(){

    [[ -z "${QITEM-}" ]] && return 1

    printf "%s\n" "${QITEM}" >> "${QUEUE_APPEND_FILE}" && return 0 || return 1

}

function QUEUE_APPEND_MANY(){

    declare -p | grep -e '^declare -[Aa] QITEM=' &> /dev/null || return 1

    [[ -z "${QITEM[@]-}" ]] && return 1

    printf "%s\n" "${QITEM[@]}" >> "${QUEUE_APPEND_FILE}" && return 0 || return 1

}

function QUEUE_READ(){

    QUEUE=()

    local QITEM

    if [[ -f ${QUEUE_FILE} ]]; then

        while IFS=$'\n' read QITEM; do
            [[ -n "${QITEM-}" ]] && QUEUE+=("${QITEM}")
        done < "${QUEUE_FILE}"

    fi

    if [[ -n "${QUEUE_APPEND_FILE}" ]] && [[ -f ${QUEUE_APPEND_FILE} ]]; then

        QITEM=

        mv "${QUEUE_APPEND_FILE}" "${QUEUE_APPEND_FILE}.tmp"

        while IFS=$'\n' read QITEM; do
         [[ -n "${QITEM-}" ]] && QUEUE+=("${QITEM}")
        done < "${QUEUE_APPEND_FILE}.tmp"

        rm "${QUEUE_APPEND_FILE}.tmp"

        QUEUE_SAVE

    fi

    return 0

}

##PRIVATE
function QUEUE_SAVE(){

    if [[ -z "${QUEUE[@]-}" ]]; then
        echo -n "" > "${QUEUE_FILE}" && return 0 || return 1
    else
        printf "%s\n" "${QUEUE[@]-}" > "${QUEUE_FILE}" && return 0 || return 1
    fi

}


function QUEUE_REMOVE_FILE(){

    local FORCE="${1-false}"

    if [[ "${FORCE}" != "true" ]]; then

        QUEUE_READ

        [[ -n "${QUEUE[@]-}" ]] && LOG "ERROR: TRYING TO REMOVE QUEUE FILE WITH ITEMS STILL QUEUED. EXITING." && QUIT 1

    fi

    [[ -f "${QUEUE_FILE}" ]] && rm "${QUEUE_FILE}"

    [[ -f "${QUEUE_APPEND_FILE}" ]] && rm "${QUEUE_APPEND_FILE}"

    return 0

}