FROM tcf909/ubuntu-slim:latest
MAINTAINER T.C. Ferguson <tcf909@gmail.com>

#
# General
#

RUN apt-get update && \
    apt-get upgrade && \
    if [ "${DEBUG}" = "true" ]; then \
        apt-get install vim iptables net-tools iputils-ping mtr; \
    fi && \
    #CURL
    apt-get purge curl || echo 'no curl ' && \
    apt-get install build-essential && \
    wget -q 'https://curl.haxx.se/download/curl-7.54.0.tar.gz' -O /tmp/curl.tar.gz && \
    apt-get install libssl-dev && \
    cd /tmp && \
    tar zxvf curl.tar.gz && \
    cd curl-* && \
    ./configure --libdir=/usr/lib/x86_64-linux-gnu && \
    make && \
    make install && \
    cd ~ && \
#cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
# Google-drive-ocamlfuse
#
#    add-apt-repository -y ppa:alessandro-strada/ppa && \
##    add-apt-repository ppa:alessandro-strada/google-drive-ocamlfuse-beta && \
#    apt-get update && \
#    apt-get install google-drive-ocamlfuse && \
##
ARG PIN_URL="google-drive-ocamlfuse https://github.com/astrada/google-drive-ocamlfuse.git#v0.6.25"

ENV OPAMROOT="/usr/local/share/opam"

RUN apt-get update && \
    apt-get install opam ocaml make fuse camlp4-extra build-essential pkg-config git && \
    groupadd fuse && \
    adduser root fuse && \
    #chown root.fuse /dev/fuse && \
    #chmod 660 /dev/fuse && \
    opam init && \
    opam update && \
    opam install depext && \
    eval `opam config env` && \
    opam pin -n add ${PIN_URL} && \
    opam depext google-drive-ocamlfuse && \
    opam install google-drive-ocamlfuse && \
#cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#RSYNC
#
EXPOSE 873

RUN apt-get update && \
    apt-get install \
        rsync && \
    #cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#WATCHER
#
RUN apt-get update && \
    apt-get install \
        inotify-tools && \
    #cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#FILEBOT
#
RUN apt-get update && \
    apt-get install \
        wget \
        openjdk-8-jre \
        libmediainfo0v5 && \
    wget -q 'http://filebot.sourceforge.net/download.php?type=deb&arch=amd64' -O /tmp/filebot-amd64.deb  && \
    dpkg --force-depends -i /tmp/filebot-*.deb && \
    #cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
# RCLONE
#
ARG RCLONE_URL=http://downloads.rclone.org/rclone-v1.39-linux-amd64.zip

RUN apt-get update && \
    apt-get install \
        unzip \
        fuse && \
    cd /tmp && \
    wget -q ${RCLONE_URL} -O rclone.zip && \
    unzip -j rclone.zip -d rclone && \
    mv /tmp/rclone/rclone /usr/local/bin/ && \
    cd ~ && \
    #cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#MERGERFS
#
ARG MERGERFS_URL=https://github.com/trapexit/mergerfs/releases/download/2.23.1/mergerfs_2.23.1.ubuntu-xenial_amd64.deb

RUN apt-get update && \
    apt-get install \
        fuse && \
    cd /tmp && \
    wget -q ${MERGERFS_URL} -O /tmp/mergerfs.deb && \
    apt-get install /tmp/mergerfs.deb && \
    cd ~ && \
    #cleanup
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
# PLEX
#
HEALTHCHECK --interval=200s --timeout=100s CMD /scripts/healthcheck.sh || exit 1

EXPOSE 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp

VOLUME /config /transcode

ENV PLEX_CHANGE_CONFIG_DIR_OWNERSHIP="true" \
    PLEX_HOME_DIR="/config"

RUN apt-get update && \
    apt-get install \
        tzdata \
        xmlstarlet \
        uuid-runtime && \
    #Add Users
    useradd -g 0 -o -u 0 -d /config -s /bin/false plex && \
    usermod -G users plex && \
    # Setup directories
    mkdir -p \
        /config \
        /transcode \
        /data && \
   #cleanup
   apt-get autoremove && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#FileSystem
COPY rootfs/ /

#
# Plex Post Build
#
#1.10.1
ARG TAG="1.10.1.4602-f54242b6b"
ARG URL="https://downloads.plex.tv/plex-media-server/1.10.1.4602-f54242b6b/plexmediaserver_1.10.1.4602-f54242b6b_amd64.deb"
#1.5.1 (working audio transcode)
#ARG TAG="1.5.1.3520-ed60c70d6"
#ARG URL="https://downloads.plex.tv/plex-media-server/1.5.1.3520-ed60c70d6/plexmediaserver_1.5.1.3520-ed60c70d6_amd64.deb"
RUN \
    #install plex
    /scripts/installBinary.sh