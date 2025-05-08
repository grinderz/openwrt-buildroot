FROM varch/openwrt-srcbuilder:latest

ARG SRC_ARTIFACTS_DIR
ARG SRC_IMG_BUILDER_FILE

USER buildbot
WORKDIR /builder/

COPY $SRC_ARTIFACTS_DIR/$SRC_IMG_BUILDER_FILE .
RUN tar xf "$SRC_IMG_BUILDER_FILE" --strip=1 --no-same-owner -C . && \
    rm -vrf "$SRC_IMG_BUILDER_FILE"

ENTRYPOINT [ ]
CMD [ "/bin/bash" ]