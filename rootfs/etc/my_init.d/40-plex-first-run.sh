#!/usr/bin/env bash
[[ "${DEBUG,,}" == "true" ]] && set -x
. "/scripts/functions.inc.sh" || { echo "ERROR: couldn't include common functions" && exit 1; }

# If the first run completed successfully, we are done
[[ "${FIRST_RUN}" == "true" ]] && exit 0

#load plex common functions
. "/scripts/plex-common.sh" || { echo "ERROR: unable to load plex common scripts." && exit 1; }

# Setup user/group ids
if [ ! -z "${PLEX_UID}" ]; then
  if [ ! "$(id -u plex)" -eq "${PLEX_UID}" ]; then
    
    # usermod likes to chown the home directory, so create a new one and use that
    # However, if the new UID is 0, we can't set the home dir back because the
    # UID of 0 is already in use (executing this script).
    if [ ! "${PLEX_UID}" -eq 0 ]; then
      mkdir /tmp/temphome
      usermod -d /tmp/temphome plex
    fi
    
    # Change the UID
    usermod -o -u "${PLEX_UID}" plex
    
    # Cleanup the temp home dir
    if [ ! "${PLEX_UID}" -eq 0 ]; then
      usermod -d /config plex
      rm -Rf /tmp/temphome
    fi
  fi
fi

if [ ! -z "${PLEX_GID}" ]; then
  if [ ! "$(id -g plex)" -eq "${PLEX_GID}" ]; then
    groupmod -o -g "${PLEX_GID}" plex
  fi
fi

# Update ownership of dirs we need to write
if [ "${PLEX_CHANGE_CONFIG_DIR_OWNERSHIP,,}" = "true" ]; then
  if [ -f "${PLEX_PREF_FILE}" ]; then
    if [ ! "$(stat -c %u "${PLEX_PREF_FILE}")" = "$(id -u plex)" ]; then
      chown -R plex:plex /config
    fi
  else
    chown -R plex:plex /config
  fi
  chown -R plex:plex /transcode
fi

# Create empty shell pref file if it doesn't exist already
if [ ! -e "${PLEX_PREF_FILE}" ]; then
  echo "Creating pref shell"
  mkdir -p "$(dirname "${PLEX_PREF_FILE}")"
  cat > "${PLEX_PREF_FILE}" <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<Preferences/>
EOF
  chown -R plex:plex "$(dirname "${PLEX_PREF_FILE}")"
fi

# Setup Server's client identifier
serial="$(getPref "MachineIdentifier")"
if [ -z "${serial}" ]; then
  serial="$(uuidgen)"
  setPref "MachineIdentifier" "${serial}"
fi

clientId="$(getPref "ProcessedMachineIdentifier")"
if [ -z "${clientId}" ]; then
  clientId="$(echo -n "${serial}- Plex Media Server" | sha1sum | cut -b 1-40)"
  setPref "ProcessedMachineIdentifier" "${clientId}"
fi

#GENERAL PREFERENCES
setPref "AcceptedEULA" "1"
setPref "PublishServerOnPlexOnlineKey" "1"

# Get server token and only turn claim token into server token if we have former but not latter.
PLEX_EXISTING_TOKEN="$(getPref "PlexOnlineToken")"

#PLEX_TOKEN
if [[ -z "${PLEX_EXISTING_TOKEN}" ]]; then

    if [ -n "${PLEX_TOKEN}" ]; then

        PLEX_EXISTING_TOKEN="${PLEX_TOKEN}"

        setPref "PlexOnlineToken" "${PLEX_TOKEN}"

    fi

    if [[ -z "${PLEX_EXISTING_TOKEN}" ]] && [[ -n "${PLEX_CLAIM}" ]]; then

        loginInfo="$(curl -X POST \
            -H 'X-Plex-Client-Identifier: '${clientId} \
            -H 'X-Plex-Product: Plex Media Server'\
            -H 'X-Plex-Version: 1.1' \
            -H 'X-Plex-Provides: server' \
            -H 'X-Plex-Platform: Linux' \
            -H 'X-Plex-Platform-Version: 1.0' \
            -H 'X-Plex-Device-Name: PlexMediaServer' \
            -H 'X-Plex-Device: Linux' \
            "https://plex.tv/api/claim/exchange?token=${PLEX_CLAIM}")"

        PLEX_EXISTING_TOKEN="$(echo "$loginInfo" | sed -n 's/.*<authentication-token>\(.*\)<\/authentication-token>.*/\1/p')"

        [[ -n "${PLEX_EXISTING_TOKEN}" ]] && setPref "PlexOnlineToken" "${PLEX_EXISTING_TOKEN}" || echo "Was not able to retrieve PLEX_TOKEN."

    fi

    if [[ -z "${PLEX_EXISTING_TOKEN}" ]] && [[ -n "${PLEX_USERNAME}" ]] && [[ -n "${PLEX_PASSWORD}" ]]; then

        PLEX_EXISTING_TOKEN="$(curl -u '${PLEX_USERNAME}':'${PLEX_PASSWORD}' 'https://plex.tv/users/sign_in.xml' \
            -X POST \
            -H 'X-Plex-Device-Name: PlexMediaServer' \
            -H 'X-Plex-Provides: server' \
            -H 'X-Plex-Version: 0.9' \
            -H 'X-Plex-Platform-Version: 0.9' \
            -H 'X-Plex-Platform: xcid' \
            -H 'X-Plex-Product: Plex Media Server' \
            -H 'X-Plex-Device: Linux' \
            -H 'X-Plex-Client-Identifier: XXXX' --compressed | sed -n 's/.*<authentication-token>\(.*\)<\/authentication-token>.*/\1/p')"

        [[ -n "${PLEX_EXISTING_TOKEN}" ]] && setPref "PlexOnlineToken" "${PLEX_EXISTING_TOKEN}" || echo "Was not able to retrieve PLEX_TOKEN."

    fi

fi

if [ ! -z "${ADVERTISE_IP}" ]; then
  setPref "customConnections" "${ADVERTISE_IP}"
fi

#ADVERTISE_DNS
if [[ ! -z "${PLEX_ADVERTISE_DNS}" ]]; then

    dnsToIp "${PLEX_ADVERTISE_DNS}" && \
        [[ ! -z "${dnsToIpResult}" ]] && \
        setPref "customConnections" "${dnsToIpResult}"

fi

if [ ! -z "${ALLOWED_NETWORKS}" ]; then
  setPref "allowedNetworks" "${ALLOWED_NETWORKS}"
fi

# Set transcoder temp if not yet set
if [ -z "$(getPref "TranscoderTempDirectory")" ]; then
  setPref "TranscoderTempDirectory" "/transcode"
fi