#!/bin/bash

PLEX_HOME_DIR="${PLEX_HOME_DIR:-$(echo ~plex)}"
PLEX_APP_SUPPORT_DIR="${PLEX_APP_SUPPORT_DIR:-${PLEX_HOME_DIR}/Library/Application Support}"
PLEX_PREF_FILE="${PLEX_APP_SUPPORT_DIR}/Plex Media Server/Preferences.xml"

function getVersionInfo {
  local version="$1"
  local token="$2"
  declare -n remoteVersion=$3
  declare -n remoteFile=$4
  
  local versionInfo
  
  if [ "${version,,}" = "plexpass" ]; then
    versionInfo="$(curl -s "https://plex.tv/downloads/details/1?build=linux-ubuntu-x86_64&channel=8&distro=ubuntu&X-Plex-Token=${token}")"
  elif [ "${version,,}" = "public" ]; then
    versionInfo="$(curl -s "https://plex.tv/downloads/details/1?build=linux-ubuntu-x86_64&channel=16&distro=ubuntu")"
  else
    versionInfo="$(curl -s "https://plex.tv/downloads/details/1?build=linux-ubuntu-x86_64&channel=8&distro=ubuntu&X-Plex-Token=${token}&version=${version}")"
  fi
  
  # Get update info from the XML.  Note: This could countain multiple updates when user specifies an exact version with the lowest first, so we'll use first always.
  remoteVersion=$(echo "${versionInfo}" | sed -n 's/.*Release.*version="\([^"]*\)".*/\1/p')
  remoteFile=$(echo "${versionInfo}" | sed -n 's/.*file="\([^"]*\)".*/\1/p')
}


function installFromUrl {
  installFromRawUrl "https://plex.tv/${1}"
}

function installFromRawUrl {
  local remoteFile="$1"
  curl -J -L -o /tmp/plexmediaserver.deb "${remoteFile}"
  local last=$?

  # test if deb file size is ok, or if download failed
  if [[ "$last" -gt "0" ]] || [[ $(stat -c %s /tmp/plexmediaserver.deb) -lt 10000 ]]; then
    echo "Failed to fetch update"
    exit 1
  fi

  dpkg -i --force-confold /tmp/plexmediaserver.deb
  rm -f /tmp/plexmediaserver.deb
}

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
