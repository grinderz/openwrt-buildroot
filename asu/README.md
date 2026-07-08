# ASU server

Self-hosted [attended sysupgrade server](https://github.com/openwrt/asu) for
`owut` / `luci-app-attendedsysupgrade`. Runs in two modes: with the official
imagebuilder image or with one built from sources (`img.src.*`).

## Services (docker-compose.yaml)

- **server** — `docker.io/openwrt/asu` (uvicorn), API on port 8000, bound to
  all interfaces so routers on the LAN can reach it.
  `BASE_CONTAINER` comes from the environment, defaults to the official image.
- **worker** — rqworker, executes builds. ASU hardcodes the podman socket path
  `/var/podman.sock`, so the worker command symlinks it to the socket from the
  shared volume.
- **podman** — privileged podman-in-docker: provides the socket for the worker
  and creates the `asu-build` network that ASU requires for build container
  isolation.
- **redis** — `redis-stack-server`, job queue.
- **registry** — local registry (`localhost:5001` from the host,
  `registry:5000` inside the compose network). ASU **always pulls** the
  imagebuilder image — a local docker image is not visible to it, so src-built
  images are published here. Podman is allowed insecure pulls via
  `registries.conf`.
- **metadata** — nginx serving static files (`asu/metadata/`) for the custom
  mode: `.versions.json`, `.targets.json`, `targets/*/profiles.json` and
  package indexes from your own src build. ASU validates the profile against
  `{upstream_url}/…/profiles.json` **before** starting a build, so devices
  absent from downloads.openwrt.org only work with your own metadata
  (`UPSTREAM_URL=http://metadata`).

Server config — `asu.toml` (`allow_defaults = true` — private server, custom
uci-defaults allowed in build requests, so any LAN client can submit arbitrary
scripts baked into images — keep the server on a trusted network;
`repository_allow_list` — allowed external repo URL prefixes).

## Make targets

```
make asu.up                             # official ghcr.io/openwrt/imagebuilder
make asu.src.up                         # src-built imagebuilder, official metadata
make asu.custom.up                      # src imagebuilder + own metadata (custom devices)
make asu.meta.publish                   # publish profiles.json/packages from the src build
make asu.push.device.rtr1-gl-mt6000     # publish an img.src image to the registry
make asu.push.profile.<name>
make asu.logs
make asu.down
```

## Cycle for a custom device (absent from the official repo)

1. `make src.all` — build from sources with the device profile
   (the profile lands in `bin/targets/.../profiles.json`);
2. `make img.src.profile.<name>` — imagebuilder image built;
3. `make asu.meta.publish` — profiles.json, `.targets.json`, `.versions.json`
   and package feeds published to `asu/metadata/`;
4. `make asu.custom.up` — server with `BASE_CONTAINER` pointing at the local
   registry and `UPSTREAM_URL` at the nginx metadata;
5. `make asu.push.profile.<name>` — image pushed to the registry;
6. router talks to `http://<host>:8000`.

Build on top of an official release (matching vermagic) so kmods install from
the published feeds.

## Tag compatibility

ASU derives the image name as `{base_container}:{target-subtarget}-{tag}`,
version-to-tag mapping (verified against ASU source):

| Requested version  | Image tag       |
|--------------------|-----------------|
| `24.10.7`          | `v24.10.7`      |
| `24.10-SNAPSHOT`   | `openwrt-24.10` |
| `SNAPSHOT`         | `master`        |

— the same scheme the `img.*` targets use (`IMG_BUILDER_IMAGE_TAG`), so pushed
images are picked up without retagging.

## Notes

- For snapshot versions ASU runs `sh setup.sh` inside the imagebuilder image
  (the official one downloads the imagebuilder on the fly). Our image ships it
  pre-unpacked — `imgbuilder.Dockerfile` adds a no-op stub.
- Custom branches (almond3s etc.) are not addressable through ASU — it only
  understands official version names.
- `asu/public/` (built image cache) and `asu/metadata/` are gitignored.
