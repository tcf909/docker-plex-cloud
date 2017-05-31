FROM tcf909/ubuntu-slim:latest
MAINTAINER T.C. Ferguson <tcf909@gmail.com>

CMD ["/sbin/my_init"]

ARG DEBIAN_FRONTEND="noninteractive"
ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"

#iTerm2 Utils
RUN curl -L https://iterm2.com/misc/install_shell_integration_and_utilities.sh | bash

#Turn off apt-get recommends and suggestions
RUN printf 'APT::Get::Assume-Yes "true";\nAPT::Install-Recommends "false";\nAPT::Get::Install-Suggests "false";\n' > /etc/apt/apt.conf.d/99defaults

##RCLONE
ARG RCLONE_URL=http://downloads.rclone.org/rclone-v1.36-linux-amd64.zip
ARG RCLONE_BUILD_DIR=/usr/local/src

##MERGERFS
ARG MERGERFS_URL=https://github.com/trapexit/mergerfs/releases/download/2.19.0/mergerfs_2.19.0.ubuntu-xenial_amd64.deb

##RSYNC
EXPOSE 873

###PLEX
EXPOSE 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp
VOLUME /config /transcode
ENV CHANGE_CONFIG_DIR_OWNERSHIP="true" \
    HOME="/config"
ARG TAG=plexpass
ARG URL=
HEALTHCHECK --interval=200s --timeout=100s CMD /scripts/healthcheck.sh || exit 1

##RUN
RUN \
    apt-get update && \
    apt-get upgrade && \
#
#GENERAL
#
    if [ "${DEBUG}" = "true" ]; then \
        apt-get update && \
        apt-get install vim iptables net-tools iputils-ping mtr && \
        apt-get autoremove && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    fi && \
#
#RCLONE
#
    apt-get install \
        wget \
        unzip \
        fuse && \
    cd ${RCLONE_BUILD_DIR} && \
    wget -q $RCLONE_URL -O rclone.zip && \
    unzip -j rclone.zip -d rclone && \
    mv ${RCLONE_BUILD_DIR}/rclone/rclone /usr/local/bin/ && \
    rm -rf ${RCLONE_BUILD_DIR}/rclone && \
#
#MERGERFS
    apt-get install \
        curl \
        fuse && \
    curl -L -o /tmp/mergerfs.deb ${MERGERFS_URL} && \
    apt-get install /tmp/mergerfs.deb && \
#
#RSYNC
#
    apt-get install rsync && \
#
#WATCHER
#
    apt-get install \
        inotify-tools && \
#
#FILEBOT
#
    apt-get install openjdk-8-jre libmediainfo0v5 && \
    mkdir -p /tmp/filebot && cd /tmp/filebot && \
    curl -o filebot-amd64.deb -L 'http://filebot.sourceforge.net/download.php?type=deb&arch=amd64' && \
    dpkg --force-depends -i filebot-*.deb && \
    cd ~ && \
#
#PLEX
#
    #packages
    apt-get install \
        tzdata \
        curl \
        xmlstarlet \
        uuid-runtime && \
    #Add Users
    useradd -U -d /config -s /bin/false plex && \
    usermod -G users plex && \
    # Setup directories
    mkdir -p \
        /config \
        /transcode \
        /data && \
#
#CLEANUP
#
   apt-get autoremove && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY rootfs/ /

RUN \
    #install plex
    /scripts/installBinary.sh