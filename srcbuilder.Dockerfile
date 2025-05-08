FROM docker.io/ubuntu:24.04

ENV GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

USER root

RUN apt update && apt install --no-install-recommends --no-install-suggests --yes \
        ca-certificates \
        build-essential \
        clang \
        flex \
        bison \
        g++ \
        gawk \
        gcc-multilib \
        g++-multilib \
        gettext \
        git \
        libncurses5-dev \
        libssl-dev \
        python3-setuptools \
        rsync \
        swig \
        unzip \
        zlib1g-dev \
        file \
        wget \
        xxd \
        quilt \
        zstd \
        7zip \
  && \
  apt-get clean && \
  rm -f -r "/var/lib/apt/" && \
  rm -f -r "/var/cache/apt/"

WORKDIR /builder

RUN \
    userdel -rfRZ ubuntu && \
    groupadd -g 1000 buildbot && \
    useradd \
      -u 1000 \
      -g 1000 \
	    --create-home --home-dir /builder \
	    --comment "OpenWrt buildbot" \
	    --gid buildbot --shell /bin/bash buildbot && \
    chown buildbot:buildbot /builder

USER buildbot

WORKDIR /builder

VOLUME [ "/builder" ]
ENTRYPOINT [ ]
CMD [ "/bin/bash" ]