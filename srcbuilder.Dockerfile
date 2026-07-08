FROM docker.io/ubuntu:24.04

SHELL ["/bin/bash", "-o", "errtrace", "-o", "pipefail", "-o", "noclobber", "-o", "errexit", "-o", "nounset", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ENV GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

USER root

RUN <<EOT
apt-get update
apt-get install --no-install-recommends --no-install-suggests --yes \
  ca-certificates \
  build-essential \
  ccache \
  clang \
  flex \
  bison \
  g++ \
  g++-multilib \
  gcc-multilib \
  gawk \
  gettext \
  git \
  libncurses-dev \
  libssl-dev \
  python3-dev \
  python3-setuptools \
  python3-venv \
  python3-pip \
  python3-pyelftools \
  python3-cryptography \
  swig \
  unzip \
  zlib1g-dev \
  file \
  curl \
  wget \
  xxd \
  quilt \
  zstd \
  7zip \
  gosu \
  libdw-dev \
  libelf-dev \
  locales \
  pv \
  pwgen \
  qemu-utils \
  rsync \
  fish \
  genisoimage
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
EOT

ENV LANG=en_US.utf8

ARG UID
ARG GID

RUN <<EOT
userdel -rfRZ ubuntu
groupadd -g ${GID} buildbot
useradd \
  --create-home --home-dir /builder \
  --comment "OpenWrt buildbot" \
  --uid ${UID} \
  --gid buildbot --shell /bin/fish buildbot
EOT

USER buildbot

WORKDIR /builder/src

VOLUME [ "/builder/src" ]
ENTRYPOINT [ ]
CMD [ "/bin/fish" ]