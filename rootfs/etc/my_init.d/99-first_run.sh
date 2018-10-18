#!/usr/bin/env bash
[[ "${DEBUG,,}" == "true" ]] && set -x

###ENVS###

###CODE###
FUNCTIONS="/scripts/functions.inc.sh"
[[ -f $FUNCTIONS ]] && . $FUNCTIONS || { echo "ERROR: couldn't include ${FUNCTIONS}" && exit 1; }

[[ "${FIRST_RUN}" == "true" ]] && exit 0

touch $FIRST_RUN_FILE #provided by functions.inc.sh