FROM tcf909/ubuntu-slim:latest
MAINTAINER T.C. Ferguson <tcf909@gmail.com>

CMD ["/sbin/my_init"]

ARG DEBIAN_FRONTEND="noninteractive"
ENV TERM="xterm-color" LANG="C.UTF-8" LC_ALL="C.UTF-8"

#iTerm2 Utils
RUN curl -L https://iterm2.com/misc/install_shell_integration_and_utilities.sh | bash

#Turn off apt-get recommends and suggestions
RUN printf 'APT::Get::Assume-Yes "true";\nAPT::Install-Recommends "false";\nAPT::Get::Install-Suggests "false";\n' > /etc/apt/apt.conf.d/99defaults

##RCLONE
ARG RCLONE_URL=http://downloads.rclone.org/rclone-v1.36-linux-amd64.zip
ARG RCLONE_BUILD_DIR=/tmp

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

ENV OPAMROOT="/usr/local/share/opam"

##RUN
RUN \
    apt-get update && \
    apt-get upgrade && \
#
#GENERAL
#
    apt-get install \
        wget && \
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
#
#RCLONE
#
    apt-get install \
        unzip \
        fuse && \
    cd ${RCLONE_BUILD_DIR} && \
    wget -q ${RCLONE_URL} -O rclone.zip && \
    unzip -j rclone.zip -d rclone && \
    mv ${RCLONE_BUILD_DIR}/rclone/rclone /usr/local/bin/ && \
    rm -rf ${RCLONE_BUILD_DIR}/rclone && \
    cd ~ && \
#
# Google-drive-ocamlfuse
#
#    add-apt-repository -y ppa:alessandro-strada/ppa && \
##    add-apt-repository ppa:alessandro-strada/google-drive-ocamlfuse-beta && \
#    apt-get update && \
#    apt-get install google-drive-ocamlfuse && \
##
    apt-get install opam ocaml make fuse camlp4-extra build-essential pkg-config git && \
    groupadd fuse && \
    adduser root fuse && \
    #chown root.fuse /dev/fuse && \
    #chmod 660 /dev/fuse && \
    opam init && \
    opam update && \
    opam install depext && \
    eval `opam config env` && \
    opam pin -n add google-drive-ocamlfuse https://github.com/astrada/google-drive-ocamlfuse.git#v0.6.19 && \
    opam depext google-drive-ocamlfuse && \
    opam install google-drive-ocamlfuse --destdir /usr/local/bin && \
#
#MERGERFS
    apt-get install \
        fuse && \
    wget -q ${MERGERFS_URL} -O /tmp/mergerfs.deb && \
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
    wget -q 'http://filebot.sourceforge.net/download.php?type=deb&arch=amd64' -O /tmp/filebot-amd64.deb  && \
    dpkg --force-depends -i /tmp/filebot-*.deb && \
    cd ~ && \
#
#PLEX
#
    #packages
    apt-get install \
        tzdata \
        #curl \
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
   #apt-get remove build-essential pkg-config && \
   apt-get autoremove && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY rootfs/ /

RUN \
    #install plex
    /scripts/installBinary.sh