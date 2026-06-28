# Openwrt src and image builder

# Requirements

- make >= 4.4.x

# TODO

- github actions https://github.com/csharper2005/openwrt-actions/tree/main/.github/workflows
- add files for almond 3S https://github.com/fildunsky/openwrt/commit/4c4f6be9a9d275e164c956df7e6e500532182f55#diff-73dd4ffe9df107bd271e3e636bbacebf6bb212f5a8ef42295f36b6c54b1d6334
- add uci-default wlan_name (WIFI)
- clean image profiles
- map packages dir + pass to src imagebuilder (local packages from src build)
- imagebuilder add DISABLED_SERVICES
- customfeeds.conf
- repositeries.conf
- make img.ib.% (package_whatdepends, package_depends, manifest)
- https://dl.openwrt.ai/releases/24.10/packages/aarch64_cortex-a53/kiddin9/
- https://downloads.immortalwrt.org/releases/24.10.2/packages/aarch64_cortex-a53/luci/luci-theme-argon_2.4.2-r20250617_all.ipk
- https://github.com/koshev-msk/modemfeed
- s3 securify https://4pda.to/forum/index.php?showtopic=1085698&view=findpost&p=137406633 https://ssclash.notion.site/ZRAM-20a89188f6b4809aa3d4f4297356a27f
- replace mtk firmware https://forum.openwrt.org/t/retired-thread-gl-inet-flint-2-gl-mt6000-snapshot-experimental-bleeding-edge/197278/39
- build pkg action https://github.com/zerolabnet/SSClash/blob/main/.github/workflows/build.ym
- https://github.com/vernette/beszel-agent-openwrt/blob/master/.github/workflows/build-package.yml
- https://github.com/bigmalloy/luci-app-fancontrol
- https://github.com/Slava-Shchipunov/awg-openwrt
- https://github.com/bigmalloy/luci-app-fancontrol
- Vermagic cat build_dir/target-*/linux-*/linux-*/.vermagic

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


# Pkgs

- beszel-agent-openwrt https://github.com/vernette/beszel-agent-openwrt
- luci-theme-proton2025 https://github.com/ChesterGoodiny/luci-theme-proton2025

# Patch

- huasifei_wh3000 fancontrol https://github.com/padavanonly/immortalwrt-mt798x-6.6/pull/211
- 

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
