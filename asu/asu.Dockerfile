# asu worker image with the tls_verify patch baked in.
#
# podman-py's pull() sends tlsVerify=true by default, which overrides the
# insecure-registry config — force it off so pulls from the plain-http
# compose-local registry work (asu itself passes no tls_verify).
#
# The grep guard makes an upstream change of the call site fail THIS BUILD
# loudly, instead of a runtime sed silently patching nothing (the previous
# approach: sed in the worker's command on every container start).
ARG ASU_IMAGE
FROM $ASU_IMAGE

RUN grep -q 'podman.images.pull(image)' /app/asu/build.py && \
    sed -i 's/podman.images.pull(image)/podman.images.pull(image, tls_verify=False)/' /app/asu/build.py
