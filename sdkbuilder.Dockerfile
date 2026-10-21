# local image built by docker-compose.yaml, latest is its only tag
# hadolint ignore=DL3007
FROM varch/openwrt-srcbuilder:latest

ARG SRC_ARTIFACTS_DIR
ARG SRC_SDK_FILE_PATTERN

USER buildbot
WORKDIR /builder/

# bind mount of the artifacts dir, not COPY: a copied archive stays in its
# own layer even after rm in a later RUN. The dir is mounted (not the file)
# because the sdk file name is a glob, which a mount source cannot expand
RUN --mount=type=bind,source=$SRC_ARTIFACTS_DIR,target=/tmp/artifacts \
    tar xf /tmp/artifacts/$SRC_SDK_FILE_PATTERN --strip=1 --no-same-owner -C .

ENTRYPOINT [ ]
CMD [ "/bin/bash" ]
