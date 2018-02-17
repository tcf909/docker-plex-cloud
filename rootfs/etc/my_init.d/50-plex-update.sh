#!/usr/bin/env bash
[[ "${DEBUG,,}" == "true" ]] && set -x
. "/scripts/functions.inc.sh" || { echo "ERROR: couldn't include common functions" && exit 1; }

# If the first run completed successfully, we are done
[[ "${FIRST_RUN}" == "true" ]] && exit 0

#load plex common functions
. "/scripts/plex-common.sh" || { echo "ERROR: unable to load plex common scripts." && exit 1; }

# Get token
PLEX_EXISTING_TOKEN="$(getPref "PlexOnlineToken")"

# Determine current version
if (dpkg --get-selections plexmediaserver 2> /dev/null | grep -wq "install"); then
  installedVersion=$(dpkg-query -W -f='${Version}' plexmediaserver 2> /dev/null)
else
  installedVersion="none"
fi

# Read set version
versionToInstall="$(cat /version.txt)"
if [ -z "${versionToInstall}" ]; then
  echo "No version specified in install.  Broken image"
  exit 1
fi

# Short-circuit test of version before remote check to see if it's already installed.
if [ "${versionToInstall}" = "${installedVersion}" ]; then
  exit 0
fi

# Get updated version number
getVersionInfo "${versionToInstall}" "${PLEX_EXISTING_TOKEN}" remoteVersion remoteFile

if [ -z "${remoteVersion}" ] || [ -z "${remoteFile}" ]; then
  echo "Could not get update version"
  exit 0
fi

# Check if there's no update required
if [ "${remoteVersion}" = "${installedVersion}" ]; then
  exit 0
fi

# Do update process
echo "Attempting to upgrade to: ${remoteVersion}"
installFromUrl "${remoteFile}"
