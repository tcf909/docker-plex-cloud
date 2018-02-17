#!/usr/bin/env bash
[[ "${DEBUG,,}" == "true" ]] && set -x
. "/scripts/functions.inc.sh" || { echo "ERROR: couldn't include common functions" && exit 1; }

#
# RUN EVERY START
#
sysctl -w fs.inotify.max_user_watches=100000
ulimit -s unlimited

#OPAM (For ocamlgoogledrive)
. /usr/local/share/opam/opam-init/init.sh > /dev/null 2> /dev/null || true

[[ "${FIRST_RUN}" == "true" ]] && exit 0
#
# BELOW THIS LINE: RUN ONLY ON CONTAINER CREATION
#
echo "HISTCONTROL=ignoreboth" >>~/.bashrc