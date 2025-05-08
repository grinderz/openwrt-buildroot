# Openwrt src and image builder

# TODO

- add fantastic repo https://fantastic-packages.github.io/packages/releases/24.10/

# Checklists

ll usr/lib/opkg/info/

## bcm47xx/mips74k

### Unpack

```
dd if=.chk of=firmware.trx bs=58+28 skip=1
dd if=firmware.trx of=firmware.bin bs=2506724 skip=1
unsquashfs firmware.bin
```

### Src default packages

* wpad-basic-mbedtls

### Profile device packages netgear_wnr3500l-v1-na

* kmod-b43
* kmod-usb-ohci
* kmod-usb2

## ramips/mt7621

### Unpack

```
dd if=-squashfs-sysupgrade.bin of=firmware.bin bs=3183208 skip=1
unsquashfs firmware.bin
```

### Src default packages

* wpad-basic-mbedtls
* uboot-envtools
* kmod-crypto-hw-eip93

### Profile device packages asus_rt-n56u-b1

* kmod-mt7603
* kmod-mt76x2
* kmod-usb3
* kmod-usb-ledtrig-usbport
* -uboot-envtools

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


### Src default packages

* fitblk
* kmod-phy-aquantia
* kmod-crypto-hw-safexcel
* wpad-basic-mbedtls
* uboot-envtools

### Profile device packages cudy_tr3000-v1

* kmod-usb3
* kmod-mt7915e
* kmod-mt7981-firmware
* mt7981-wo-firmware

### Profile device packages glinet_gl-mt6000

* e2fsprogs
* f2fsck
* mkf2fs
* kmod-usb3
* kmod-mt7915e
* kmod-mt7986-firmware
* mt7986-wo-firmware

### Profile device packages xiaomi_mi-router-ax3000t-ubootmod

* kmod-mt7915e
* kmod-mt7981-firmware
* mt7981-wo-firmware

## bcm27xx/bcm2710

### Unpack

```
gzip -d -squashfs-sysupgrade.img.gz
dd if=-squashfs-sysupgrade.img of=firmware.bin bs=75497472 skip=1
unsquashfs firmware.bin
```

### Src default packages

* 

### Profile device packages rpi-3

* cypress-firmware-43430-sdio
* brcmfmac-nvram-43430-sdio
* cypress-firmware-43455-sdio
* brcmfmac-nvram-43455-sdio
* kmod-brcmfmac
* wpad-basic-mbedtls
* iwinfo

## x86/64

### Unpack

```
gzip -d -squashfs-rootfs.img.gz
unsquashfs -squashfs-rootfs.img
```

### Src default packages

* 

### Profile device packages generic

* kmod-amazon-ena
* kmod-amd-xgbe
* kmod-bnx2
* kmod-dwmac-intel
* kmod-e1000e
* kmod-e1000
* kmod-forcedeth
* kmod-fs-vfat
* kmod-igb
* kmod-igc
* kmod-ixgbe
* kmod-r8169
* kmod-tg3
* kmod-drm-i915

# Deprecated config since 24.10.1

## GENERIC_SED_LINE_DELETE

- CONFIG_BPF_TOOLCHAIN_BUILD_LLVM=y
- CONFIG_HAS_BPF_TOOLCHAIN=y
- CONFIG_USE_LLVM_BUILD=y
