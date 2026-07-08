FROM varch/openwrt-srcbuilder:latest

ARG SRC_ARTIFACTS_DIR
ARG SRC_IMG_BUILDER_FILE

USER buildbot
WORKDIR /builder/

COPY $SRC_ARTIFACTS_DIR/$SRC_IMG_BUILDER_FILE .
# setup.sh no-op: asu runs it for snapshot builds to download the imagebuilder,
# but here it is already unpacked
RUN tar xf "$SRC_IMG_BUILDER_FILE" --strip=1 --no-same-owner -C . && \
    rm -vrf "$SRC_IMG_BUILDER_FILE" && \
    { [ -f setup.sh ] || printf '#!/bin/sh\nexit 0\n' > setup.sh; }

ENTRYPOINT [ ]
CMD [ "/bin/bash" ]
