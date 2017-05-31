#!/usr/bin/env bash
[[ "${DEBUG}" == "true" ]] && set -x

set -u -o pipefail

trap "QUIT" INT

trap "QUIT_FORCE" TERM

INCLUDE_PATH="/scripts/inc"

#PROVIDES:
# LOCK_SET, LOCK_UNSET, LOCK_IS
#USES:
# LOCK_FILE
. "${INCLUDE_PATH}/LOCK.inc.sh"

#PROVIDES:
# QUEUE_SHIFT, QUEUE_UNSHIFT, QUEUE_PUSH, QUEUE_PUSH_MANY, QUEUE_PUSH_FAIL, QUEUE_READ
#USES:
# QUEUE, QITEM
. "${INCLUDE_PATH}/QUEUE.inc.sh"


function SHOW_HELP(){

    echo "NOT RUNNING PIPE CORRECTLY. YOU NEED HELP."

}


function LOG(){

    echo "PIPE ${LOG_PREFIX-}${@}"

}

function LOG_PREFIX_DEFAULT(){

    LOG_PREFIX="CMD (${CMD}) "

}

function RUN(){

    local QITEM="${1}"
    local CMD_ACTUAL="${CMD/"{}"/"\"${QITEM-}\""}"

    LOG "RUNNING COMMAND (${CMD_ACTUAL})"

    (

        trap : INT TERM
        PID=$(sh -c 'echo $PPID');
        STATUS_PATH="${PIPE_TMP_DIR}/${PID}${STATUS_SUFFIX}"
        LOG_PATH="${PIPE_TMP_DIR}/${PID}${LOG_SUFFIX}"
        LOG_PREFIX="${LOG_PREFIX}JOB (${PID}) "

        LOG "STARTING"

        [[ -e "${STATUS_PATH}" ]] && rm "${STATUS_PATH}" &> /dev/null

        touch "${LOG_PATH}"

        eval "trap 'exit 129' INT TERM; ${CMD_ACTUAL}" 2>&1 | tee "${LOG_PATH}" | while read LINE; do
            [[ "${PIPE_OUTPUT_CMD_LOG-}" == "true" ]] && LOG "CMD OUTPUT: ${LINE}"
        done

        STATUS="${PIPESTATUS[0]}";

        echo "${STATUS}" > "${STATUS_PATH}"

        LOG "COMPLETE. STATUS (${STATUS})."

    ) &

     #save pid of background job
    PID=$!

    #fail if for some reason the pid couldn't be realized
    [[ -z "${PID-}" ]] && LOG "ERROR: COULD NOT DETERMINE PID" && exit 1

    #add pid to associative array with QITEM as key
	PIDS["${QITEM}"]="${PID}"

    #eval "${CMD_ACTUAL}" 2>&1 | tee "${LOG_PATH}" | while read LINE; do
    #    [[ "${PIPE_OUTPUT_CMD_LOG-}" == "true" ]] && LOG "CMD OUTPUT: ${LINE}"
    #done

    return 0

}

function RUN_KILL(){

    local PID="${1}"
    local CHILDREN="$(ps --ppid "${PID}" -o pid --noheaders)"

    [[ -n "${CHILDREN-}" ]] && for CHILD in ${CHILDREN}; do

        ps -p ${CHILD} &> /dev/null && RUN_KILL ${CHILD}

    done

    kill -9 ${PID} &> /dev/null

    return 0

}

function RUN_WAITFORANY(){

    set +x

    local PID=

    echo "WAITING FOR A JOB TO COMPLETE (${PIDS[@]-})..."

    while [[ -n "${PIDS[@]-}" ]]; do

        for PID in "${PIDS[@]-}"; do

            ps -p ${PID} > /dev/null || break 2

        done

        sleep 1

    done;

    [[ "${DEBUG-}" == "true" ]] && set -x

    return 0

}


function QUIT(){

    [[ "${DEBUG}" == "true" ]] && set -x

    trap "QUIT_FORCE" TERM

    RUN_STOP_ALL

    LOCK_UNSET

    exit ${1-}

}

function QUIT_FORCE(){

    [[ "${DEBUG}" == "true" ]] && set -x

    RUN_STOP_ALL "true"

    LOCK_UNSET

    exit ${1-}

}

function RUN_STOP_ALL(){

    local FORCE="${1:-false}"

    LOG_PREFIX_DEFAULT

    LOG "STOPPING JOBS"

    while [[ -n "${PIDS[@]-}" ]]; do

        RUN_CHECK

        for QITEM in "${!PIDS[@]}"; do

            PID="${PIDS["${QITEM}"]}"

            LOG "(${QITEM}) JOB (${PID}) STOPPING..."

            [[ "${FORCE-}" == "true" ]] && RUN_KILL ${PID} || kill ${PID}

        done

        RUN_CHECK

        [[ -n "${PIDS[@]-}" ]] && sleep 5

    done

    LOG_PREFIX_DEFAULT

    LOG "STOPPING JOBS DONE"

}



function RUN_CHECK(){

    local FAILED_COUNT=
    local PID_COUNT=

    LOG "CHECKING FOR FINISHED JOBS..."

    #Go through all jobs and see if they completed
    for QITEM in "${!PIDS[@]}"; do

        local JOB_STATUS=""
        PID="${PIDS["${QITEM}"]}"
        STATUS_PATH="${PIPE_TMP_DIR}/${PID}${STATUS_SUFFIX}"
        LOG_PATH="${PIPE_TMP_DIR}/${PID}${LOG_SUFFIX}"

        ## IF the pid is still running, skip processing a running job
        ps -p ${PID} > /dev/null && continue

        LOG_PREFIX="(${QITEM}) JOB (${PID}) "

        LOG "PROCESSING RESULTS..."

        ##If the pid isn't running and the status path hasn't been written to, set job status to greater than 128 to requeue
        [[ -e ${STATUS_PATH} ]] && read JOB_STATUS < "${STATUS_PATH}" || JOB_STATUS=129

        LOG "STATUS (${JOB_STATUS})"

        if [[ "${PIPE_OUTPUT_CMD_LOG}" != "true" ]] && [[ "${JOB_STATUS}" != "0" ]] || [[ "${DEBUG}" == "true" ]]; then

            while read LINE; do
                LOG "LOG OUTPUT: ${LINE}"
            done < "${LOG_PATH}"

        fi

        if [[ "${JOB_STATUS}" != "0" ]]; then

            if (( "${JOB_STATUS}" > 128 )); then

                LOG "JOB CAUGHT EXIT SIGNAL. ADDING BACK TO QUEUE."

                QUEUE_UNSHIFT

            else

                 #Increment total failed count
                (( FAILED++ ))

                #Increment item failed count
                QUEUE_FAILED["${QITEM}"]=$((${QUEUE_FAILED["${QITEM}"]:-0} + 1))

                local FAILED_COUNT="${QUEUE_FAILED["${QITEM}"]}"

                LOG "INCREMENTED FAILED COUNT. ITEM (${FAILED_COUNT-}) TOTAL (${FAILED-})"

                if (( "${FAILED_COUNT}" < "${PIPE_MAX_FAILED_PER_QITEM}" )); then

                    LOG "ADDING BACK TO QUEUE"

                    QUEUE_PUSH

                else

                    LOG "EXCEEDED MAX FAILURES (${PIPE_MAX_FAILED_PER_QITEM}). NOT RETURNING TO QUEUE."

                    QUEUE_PUSH_FAIL

                 fi

            fi

        else

            (( ${FAILED} > 0 )) && ((FAILED--))

            LOG "DECREMENTED FAILED COUNT. TOTAL (${FAILED-})"

        fi

        LOG "CLEANING TEMP FILES..."
        [[ -e ${STATUS_PATH} ]] && rm "${STATUS_PATH}"
        [[ -e ${LOG_PATH} ]] && rm "${LOG_PATH}"

        ##save the index
        unset 'PIDS[${QITEM}]' || exit 1

        LOG "REMOVED FROM ACTIVE JOBS LIST"

        LOG_PREFIX_DEFAULT

    done

    LOG "DONE CHECKING FOR FINISHED JOBS"

    local PID_COUNT=0

    [[ -n "${PIDS[@]-}" ]] && PID_COUNT="${#PIDS[@]}"

    LOG "JOBS STILL RUNNING (${PID_COUNT-})"

}

while getopts hvt: opt; do
    case $opt in
        h)  SHOW_HELP
            exit 0
            ;;
        v)  DEBUG=TRUE
            ;;
        t)  PIPE_MAX_THREADS="$OPTARG"
            ;;
        *)  SHOW_HELP >&2
            exit 1
            ;;
    esac
done

shift "$((OPTIND-1))" # Shift off the options and optional --.

PIPE_TMP_DIR="${PIPE_TMP_DIR:-/tmp}"
PIPE_OUTPUT_CMD_LOG="${PIPE_OUTPUT_CMD_LOG:-true}"
PIPE_QUEUE_IFS=${PIPE_QUEUE_IFS:-$'\n\t'}
PIPE_MAX_FAILED=10
PIPE_MAX_FAILED_PER_QITEM=2
PIPE_MAX_THREADS="${PIPE_MAX_THREADS:-1}"

CMD="${@}"
CMD_MD5="$(printf '%s' "${CMD[@]}" | md5sum | awk '{print $1}')"
QUEUE_FILE="${PIPE_TMP_DIR}/${CMD_MD5}.queue"
QUEUE_APPEND_FILE="${PIPE_TMP_DIR}/${CMD_MD5}.append"
QUEUE_FILE_ORIG="${PIPE_TMP_DIR}/${CMD_MD5}.queue"
QUEUE_FILE_FAILED="${PIPE_TMP_DIR}/${CMD_MD5}.failed"
LOCK_FILE="${PIPE_TMP_DIR}/${CMD_MD5}.lock"
LOG_SUFFIX=".log"
STATUS_SUFFIX=".status"
FAILED=0

unset QUEUE && declare -a QUEUE
unset QUEUE_NEW && declare -a QUEUE_NEW
unset QUEUE_FAILED && declare -A QUEUE_FAILED
unset PIDS && declare -A PIDS

[[ -z "${CMD-}" ]] && SHOW_HELP && exit 1

[[ -p /dev/fd/0 ]] && while IFS=$"${PIPE_QUEUE_IFS}" read -r -t 1 QITEM; do
    [[ -z "${QITEM-}" ]] && continue
    QUEUE_NEW+=("${QITEM}")
done && unset QITEM

#Append potential ondisk queue with incoming items
[[ -n "${QUEUE_NEW[@]-}" ]] && { QITEM=("${QUEUE_NEW[@]}") && QUEUE_APPEND_MANY && unset QITEM || exit 1; }

#LOCK OR echo back the cmd_md5
LOCK_SET || { echo "${CMD_MD5}" && exit 0; }

unset QUEUE_NEW

while QUEUE_SHIFT; do

    #Clear log prefix
    LOG_PREFIX_DEFAULT

    LOG "QUEUED ITEMS WAITING FOR PROCESSING ($((${#QUEUE[@]} + 1)))..."

    #recognize QUEUE_SHIFT gives us QITEM
    QITEM="${QITEM}"

    [[ -z "${QITEM-}" ]] && continue

    [[ -n "${PIDS["${QITEM}"]:-}" ]] && LOG "Trying to run duplicate QITEM (${QITEM}) that is already running. Skipping." && continue

    LOG_PREFIX="(${QITEM}) "

    LOG "PROCESSING"

    #execute the given command
    RUN "${QITEM}"

    #clear log prefix (will be carried in to subshell so no need to keep it)
	LOG_PREFIX_DEFAULT

    COUNT=0
    COUNT_INCREMENT=60

    #run through a waiting pattern if there are no more jobs or we are at our max threads
    while JOB_COUNT="$(jobs -rp | wc -l | tr -d '[:space:]')" && (( "${JOB_COUNT}" >= "${PIPE_MAX_THREADS}" )) || { [[  -z "${QUEUE[@]-}" ]] && [[ -n "${PIDS[@]-}" ]]; }; do

        set +x

        sleep 1

        INCREMENT=$((COUNT % COUNT_INCREMENT))

        if (( $INCREMENT == 0 )); then

            COUNT=1

            QUEUE_READ

            [[ -n "${PIDS[@]-}" ]] && PID_COUNT="${#PIDS[@]}"

            LOG "JOB RUNNING (${JOB_COUNT}), JOBS TRACKING (${PID_COUNT-0}), QUEUE COUNT (${#QUEUE[@]})"


        else

            (( COUNT++ ))

            for PID in "${PIDS[@]-}"; do

                ps -p ${PID} > /dev/null || { RUN_CHECK && break; }

            done

        fi

    done

    [[ "${DEBUG}" == "true" ]] && set -x

    if (( ${FAILED} > 0 )); then

        (( "${FAILED}" >= "${PIPE_MAX_FAILED}" )) && { LOG "EXCEEDED MAX TOTAL FAILED (${PIPE_MAX_FAILED}). EXITING."; QUIT 1; }

        echo "FAILED COUNT (${FAILED}), THROTTLING FOR $(( 2 ** ${FAILED} )) SECONDS" && sleep "$(( 2 ** ${FAILED} ))" &

        wait $!

    fi

done

LOG "DONE"

QUEUE_REMOVE_FILE
LOCK_UNSET && exit 0