#!/bin/bash
#Supported Environmental Variables:
#PLEX_USERNAME required (or PLEX_TOKEN) Example: abc@abc.com
#PLEX_PASSWORD required (or PLEX_TOKEN) Example: aslkn3rln32b
#PLEX_TOKEN require (or PLEX_USERNAME and PLEX_PASSWORD) Example: 13rb13rkjb1rkbr2tb2tb
#PLEX_ADVERTISE_DNS optional Example: http://plex.cornercafe.net:32400,https://plex.cornercafe.net:32400

# RCLONE_CONF_PATH optional Default: /etc/pod/rclone/rclone.conf
# RCLONE_DEFAULT_OPTIONS optional Default: --allow-other

#ACDCLI_OAUTH_DATA required (if not already on the system) Example: (Use the json token provided by ACDCLI)
#ACDCLI_FORCE_OAUTH_UPDATE_FROM_ENV optional Example: true (This will force the system to write $ACD_OAUTH_DATA to cache directory
#ACDCLI_CACHE_PATH optional Default: ~/.acdcli/cache
#ACDCLI_SETTINGS_PATH optional Default: ~/.acdcli/settings
#ACDCLI_DEFAULT_OPTIONS optional Example:

#ENCFS_CONFIG_PASSWORD required Example: 2r3lnk23kn32lt
#ENCFS_CONFIG_PATH optional Default: /etc/pod/encfs/encfs.xml
#ENCFS_DEFAULT_OPTIONS optional Example:

#the below are templates where # is a positive integer so you can have multiple of each kind. IE: RCLONE_MOUNT_0, RCLONE_MOUNT_1, etc... Must be sequentially order, starting with 0 and have no gaps.

#RCLONE_MOUNT_# optional Example: ACD:Path/to/remote/folder|/local/absolute/mount/path
#RCLONE_MOUNT_#_OPTIONS optional Example: --allow-other --checkers 16 --max-read-ahead 200m

#ACDCLI_MOUNT_# optional Example:
#ACDCLI_MOUNT_#_OPTIONS optional Example

#ENCFS_MOUNT_# optional Example: /local/encrypted/path|/local/unencrypted/path|fuse.ACDFuse
#ENCFS_MOUNT_#_OPTIONS optional Example:
#ENCFS_MOUNT_#_FUSE_OPTIONS optional Example: -o fuse_option1,fuse_option2,etc

#docker run -it --name plex -e "HOSTNAME=MediaServer" -e "RCLONE_MOUNT_0=ACD_VAULT:Media/Movies|/data/Movies" -e "RCLONE_MOUNT_0_OPTIONS=--transfers 10 --checkers 10 --allow-other" "$@" --cap-add SYS_ADMIN --device /dev/fuse -p 32400:32400 plex /bin/bash
docker run -it --name plex "$@" --cap-add SYS_ADMIN --device /dev/fuse -p 32400:32400 plex /bin/bash
