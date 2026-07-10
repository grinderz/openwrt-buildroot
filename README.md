# Openwrt src and image builder

# Requirements

- make >= 4.4.x
- tar, zstd (artifact archiving)
- wget, curl, jq, rsync, quilt
- docker with compose plugin (imagebuilder, sdk, asu targets)

# Usage

Version is selected via `OWRT_RELEASE` (default `24.10.7`), one file per version
in `versions/`. Source target/subtarget via `SRC_TARGET`/`SRC_SUBTARGET`
(default `ramips/mt7621`):

```
make info OWRT_RELEASE=master
make info SRC_TARGET=mediatek SRC_SUBTARGET=filogic
make src.clone OWRT_RELEASE=master-almond3s
make src.all SRC_TARGET=mediatek SRC_SUBTARGET=filogic
make img.profile.rpi-4
make pkg.<package>              # build a package with the official openwrt/sdk image
make pkg.htop SRC_TARGET=mediatek SRC_SUBTARGET=filogic
make pkg.sdk.<package>          # build a package with the SDK from src build, results in artifacts/pkg/
```

Persistent selection: `export OWRT_RELEASE=... SRC_TARGET=... SRC_SUBTARGET=...`
(e.g. in `.envrc`).

## Targets used in this project

| `SRC_TARGET/SRC_SUBTARGET` | srcbuilder configs | imagebuilder profiles / devices |
|----------------------------|--------------------|---------------------------------|
| `ramips/mt7621` (default)  | 24.10.7, 25.12.5, master | asus_rt-n56u-b1; securifi_almond-3s (24.10.7/25.12.5 via patch, master); device: rtr3-almond-s3 |
| `mediatek/filogic`         | 24.10, 24.10.7, 25.12, 25.12.5, master | cudy_ap3000-v1, cudy_m3000-v1, cudy_m3000-v2-yt8821 (master), cudy_tr3000-256mb-v1, cudy_tr3000-v1-ubootmod, xiaomi_mi-router-ax3000t-ubootmod; device: rtr1-gl-mt6000 |
| `bcm27xx/bcm2710`          | 24.10.7            | rpi-3; device: nut-rpi-3 |
| `bcm27xx/bcm2711`          | 24.10.7            | rpi-4 |
| `bcm47xx/mips74k`          | 24.10.7            | netgear_wnr3500l-v1-na |
| `rockchip/armv8`           | 24.10.7            | friendlyarm_nanopi-r3s |
| `sunxi/cortexa53`          | 24.10.7            | xunlong_orangepi-zero3 |
| `x86/64`                   | 24.10.7            | generic; device: demo-lec-7233 |

# Custom feeds / repositories

- src build: `srcbuilder/feeds-extra.conf` (or per-version
  `srcbuilder/<version>/feeds-extra.conf`) is appended to `feeds.conf.default`
  by `src.install.feeds`. See `feeds-extra.conf.example`.
- imagebuilder: `repositories-extra.conf` from `imagebuilder/<version>/`,
  `.../profiles/<name>/` and `.../devices/<name>/` are **concatenated** in
  that order (all that exist, not first-match) and appended to
  `repositories.conf` inside the container (signature check is disabled when
  custom repos are present). Overlapping lines produce harmless
  "Duplicate src declaration" opkg warnings — keep each repo in one file.
- sdk: `sdkbuilder/feeds-extra.conf` is appended to `feeds.conf.default`
  inside the SDK container.
- asu: `repository_allow_list` in `asu/asu.toml` whitelists external repo URL
  prefixes for client build requests.

SDK archive is produced by the src build (`CONFIG_SDK=y`) and stored next to the
imagebuilder archive in `artifacts/src/<version>/`. `pkg.sdk.%` builds the SDK
docker image from it, then compiles the package from feeds. Local package
sources placed in `sdkbuilder/packages/<name>/` are mounted into the SDK and
take precedence over feeds.

# ASU server

Self-hosted [attended sysupgrade server](https://github.com/openwrt/asu) for
`owut` / `luci-app-attendedsysupgrade`, API on `http://<host>:8000`. Services,
make targets, custom-device cycle, tag mapping — see [asu/README.md](asu/README.md).

# TODO

- github actions https://github.com/csharper2005/openwrt-actions/tree/main/.github/workflows
- make img.ib.% (package_whatdepends, package_depends, manifest)
- replace mtk firmware https://forum.openwrt.org/t/retired-thread-gl-inet-flint-2-gl-mt6000-snapshot-experimental-bleeding-edge/197278/39
- build pkg action https://github.com/zerolabnet/SSClash/blob/main/.github/workflows/build.yml
- https://github.com/vernette/beszel-agent-openwrt/blob/master/.github/workflows/build-package.yml
- https://github.com/bigmalloy/luci-app-fancontrol

# Repos

## fantastic

- src: https://github.com/fantastic-packages/packages/tree/24.10 
- bin: https://github.com/fantastic-packages/releases/tree/archive/24.10

## routerich

- bin: https://github.com/routerich/packages.routerich/tree/24.10.5/routerich

## modem extras

- bin: https://github.com/4IceG/Modem-extras/tree/main/myrepo

## modemfeed

- src: https://github.com/koshev-msk/modemfeed.git
- bin: 

## kiddin9

- bin: https://dl.openwrt.ai/packages-24.10/*/kiddin9/


# Patch

- huasifei_wh3000 fancontrol https://github.com/padavanonly/immortalwrt-mt798x-6.6/pull/211

# Checklists

ll usr/lib/opkg/info/

## bcm47xx/mips74k

### Unpack

```
dd if=.chk of=firmware.trx bs=58+28 skip=1
dd if=firmware.trx of=firmware.bin bs=2506724 skip=1
unsquashfs firmware.bin
```

## ramips/mt7621

### Unpack

```
dd if=-squashfs-sysupgrade.bin of=firmware.bin bs=3183208 skip=1
unsquashfs firmware.bin
```

## mediatek/filogic

### Unpack

```
tar -xvf -squashfs-sysupgrade.bin
unsquashfs root
```

### Unpack ITB

```
dd if=-squashfs-sysupgrade.itb of=firmware.bin bs=5668864 skip=1
unsquashfs firmware.bin
```

## bcm27xx/bcm2710

### Unpack

```
gzip -d -squashfs-sysupgrade.img.gz
dd if=-squashfs-sysupgrade.img of=firmware.bin bs=75497472 skip=1
unsquashfs firmware.bin
```

## x86/64

### Unpack

```
gzip -d -squashfs-rootfs.img.gz
unsquashfs -squashfs-rootfs.img
```


# ImageBuilder in standalone mode (with patched kmod)

```Makefile
CONFIG_LINE_ADD := \
	CONFIG_BUILDBOT=n \
	CONFIG_IB_STANDALONE=y \
	\
	
CONFIG_SED_LINE_DELETE := \
	CONFIG_BUILDBOT=y \
	CONFIG_IB_STANDALONE=n \
	\
```
