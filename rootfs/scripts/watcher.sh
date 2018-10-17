#!/usr/bin/env bash
[[ "${DEBUG}" == "true" ]] && set -x

SOURCE="${1}" && shift
WATCHER_OPTIONS="${WATCHER_OPTIONS:--e create -e moved_to}"

# Check if inotofywait is installed.
hash inotifywait 2>/dev/null
if [ $? -eq 1 ]; then
  echo "Unable to execute the script. Please make sure that inotify-utils
  is installed in the system."
  exit 1
fi

function cleanup {
  trap - HUP INT TERM QUIT EXIT
  kill $(pgrep -P $$) &> /dev/null
  exit $1
}

trap cleanup HUP INT TERM QUIT EXIT

inotifywait -m --format '%w%f' ${WATCHER_OPTIONS} "${SOURCE}" | \
while read FILE; do

    [[ ! -e ${FILE} ]] && continue

    [[ "${FILE}" == "${SOURCE}" ]] && echo "Event on root path with no file. Skipping." && continue

    ORIG_CMD="${*}"
    CMD="$(echo "${*}")"
    CMD_ACTUAL="${CMD//'${FILE}'/"\"${FILE-}\""}"
    echo "WATCHER EVENT (${FILE}) RUNNING (${CMD_ACTUAL})..."

    /bin/bash -c "${CMD_ACTUAL}" &

done &
wait $!
cleanup