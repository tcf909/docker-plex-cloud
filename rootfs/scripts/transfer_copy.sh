#!/usr/bin/env bash
[[ "${DEBUG}" == "true" ]] && set -x

set -u -o pipefail

SOURCE_DIR="${1}" && shift
DEST_DIR="${1}" && shift
FILE_PATHS=("${@}")

. "$(dirname "$0")/inc/RCLONE.inc.sh"

RCLONE_TRANSFER_FILES_RELATIVE "copy" "${SOURCE_DIR}" "${DEST_DIR}" "${FILE_PATHS[@]}"