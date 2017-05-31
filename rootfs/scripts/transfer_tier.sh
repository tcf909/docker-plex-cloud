#!/usr/bin/env bash
[[ "${DEBUG-}" == "true" ]] && set -x

set -u -o pipefail

SOURCE_DIR="${1}"
DEST_DIR="${2}"
LOCK_FILE="/tmp/transfer_tier.lock"

function LOG(){

    echo "TIER: ${@}"

}

[[ ! -e ${SOURCE_DIR} ]] && LOG "SOURCE_DIR (${SOURCE_DIR}) DOES NOT EXIST. EXITING." && exit 1

. "$(dirname "$0")/inc/LOCK.inc.sh"

. "$(dirname "$0")/inc/RCLONE.inc.sh"



function CHECK_SPACE(){

    TOTAL_MBS="$(df -m "${SOURCE_DIR}"  | tail -1 | awk '{print $2}')"

    FREE_MBS="$(df -m "${SOURCE_DIR}" | tail -1 | awk '{print $4}')"

    FREE_PERCENT=$((200*${FREE_MBS}/${TOTAL_MBS} % 2 + 100*${FREE_MBS}/${TOTAL_MBS}))

    #LOG "${FREE_MBS} MB AVAILABLE / ${TOTAL_MBS} MB TOTAL (${FREE_PERCENT}% FREE)"

    if (( FREE_PERCENT < STAGE_4_PERCENT )); then
        MAX_JOBS="${STAGE_4_JOBS}"
    elif (( FREE_PERCENT < STAGE_3_PERCENT )); then
        MAX_JOBS="${STAGE_3_JOBS}"
    elif (( FREE_PERCENT < STAGE_2_PERCENT )); then
        MAX_JOBS="${STAGE_2_JOBS}"
    else
        MAX_JOBS="${STAGE_1_JOBS}"
    fi

    (( ${FREE_PERCENT} > ${STAGE_1_PERCENT} )) && return 0 ||  return 1

}

LOCK_SET || exit 0

STAGE_1_PERCENT=50
STAGE_1_JOBS=1

STAGE_2_PERCENT=40
STAGE_2_JOBS=5

STAGE_3_PERCENT=30
STAGE_3_JOBS=10

STAGE_4_PERCENT=15
STAGE_4_JOBS=20

while ! CHECK_SPACE; do

    LOG "Free % (${FREE_PERCENT}) below concern % (${STAGE_1_PERCENT}). Working to free up space..."

    mapfile -t FILES <<< "$(find "${SOURCE_DIR}" -type f -printf "%T+ %p\n" | grep -v "/data/.Local/Incoming" | sort | cut -d' ' -f2-)"

    [[ -z "${FILES[@]-}" ]] && LOG "No files found. Exiting." && break;

    for FILE_PATH in "${FILES[@]-}"; do

        [[ -z "${FILE_PATH}" ]] && continue

        while ! CHECK_SPACE && JOB_COUNT="$(jobs -rp | wc -l | tr -d '[:space:]')" && (( "${JOB_COUNT}" >= "${MAX_JOBS}" )); do

            LOG "JOB COUNT (${JOB_COUNT}), MAX JOBS (${MAX_JOBS}), FREE SPACE (${FREE_PERCENT}%)"

            sleep 30

        done

        #if we are below concern percent stop loop
        CHECK_SPACE && break;

        fuser -s "${FILE_PATH}" && continue

        LOG "Moving (${FILE_PATH})..."

        RCLONE_TRANSFER_FILES_RELATIVE "move" "${SOURCE_DIR}" "${DEST_DIR}" "${FILE_PATH}" && find "$(dirname "${FILE_PATH}")" -type d -empty -delete -print &

    done

    sleep 5

done

LOG "Free % (${FREE_PERCENT})."

#Make sure all background jobs are done
wait

LOCK_UNSET