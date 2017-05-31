#!/usr/bin/with-contenv bash
[[ "${DEBUG}" == "true" ]] && set -x

FIRST_RUN_FILE="/.firstRun"
PLEX_HOME_DIR="${PLEX_HOME_DIR:-$(echo ~plex)}"
PLEX_APP_SUPPORT_DIR="${PLEX_APP_SUPPORT_DIR:-${PLEX_HOME_DIR}/Library/Application Support}"
PLEX_PREF_FILE="${PLEX_APP_SUPPORT_DIR}/Plex Media Server/Preferences.xml"

[[ -e ${FIRST_RUN_FILE} ]] && FIRST_RUN=true || FIRST_RUN=false

function getPref {
  local key="$1"
  xmlstarlet sel -T -t -m "/Preferences" -v "@${key}" -n "${PLEX_PREF_FILE}"
}

function setPref {
  local key="${1}"
  local value="${2}"
  count="$(xmlstarlet sel -t -v "count(/Preferences/@${key})" "${PLEX_PREF_FILE}")"
  count=$(($count + 0))
  if [[ $count > 0 ]]; then
    xmlstarlet ed --inplace --update "/Preferences/@${key}" -v "${value}" "${PLEX_PREF_FILE}"
  else
    xmlstarlet ed --inplace --insert "/Preferences"  --type attr -n "${key}" -v "${value}" "${PLEX_PREF_FILE}"
  fi
}

function updatePref {

    local key="${1}"
    local value="${2}"

    { [[ -z "${PLEX_PREF_FILE}" ]] || [[ -z "${key}" ]] || [[ -z "${value}" ]]; } && return 1

    local token="$(getPref "PlexOnlineToken")"

    [[ ! -z "${token}" ]] && PLEX_TOKEN="&X-Plex-Token=${token}"

    EXEC="$(curl -X PUT "http://localhost:32400/:/prefs?${key}=${value}${PLEX_TOKEN}")"

    return $?

}

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