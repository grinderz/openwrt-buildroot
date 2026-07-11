FROM varch/openwrt-srcbuilder:latest

ARG SRC_ARTIFACTS_DIR
ARG SRC_SDK_FILE_PATTERN

USER buildbot
WORKDIR /builder/

COPY $SRC_ARTIFACTS_DIR/$SRC_SDK_FILE_PATTERN ./
RUN tar xf openwrt-sdk-*.tar.zst --strip=1 --no-same-owner -C . && \
    rm -vf openwrt-sdk-*.tar.zst

ENTRYPOINT [ ]
CMD [ "/bin/bash" ]
