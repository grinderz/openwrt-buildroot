MAKEFLAGS += --warn-undefined-variables
DEV_SHELL ?= /bin/bash

SHELL := /usr/bin/env bash -o errtrace -o pipefail -o noclobber -o errexit -o nounset

IMAGE ?= quay.io/openwrt/imagebuilder
IMAGE_RELEASE ?= 24.10.0
ARTIFACTS_PATH := artifacts

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk command is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

DEFAULT_GOAL := help
.PHONY: help
help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9\-\\.%]+:.*?##/ { printf "  \033[36m%-29s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

$(ARTIFACTS_PATH):
	mkdir -p $@


.PHONY: clean
clean: ## Clean artifacts
	rm -rf "$(ARTIFACTS_PATH)"

.PHONY: clean.files
clean.files: ## Clean config files
	rm -rf "$(ARTIFACTS_PATH)"/files

.PHONY: image.netgear_wnr3500l-v1-na
image.netgear_wnr3500l-v1-na: $(ARTIFACTS_PATH) clean.files ## Build image netgear_wnr3500l-v1-na
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=bcm47xx%2Fmips74k&id=netgear_wnr3500l-v1-na
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):bcm47xx-mips74k-$(IMAGE_RELEASE) \
	make image PROFILE=netgear_wnr3500l-v1-na PACKAGES="base-files ca-bundle dnsmasq dropbear firewall4 fstools kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables nvram otrx procd-ujail swconfig uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-b43 kmod-usb-ohci kmod-usb2 luci -ppp -ppp-mod-pppoe -ip6tables -odhcp6c -kmod-ipv6 -kmod-ip6tables -odhcpd-ipv6only -opkg"

.PHONY: image.asus_rt-n56u-b1
image.asus_rt-n56u-b1: $(ARTIFACTS_PATH) clean.files ## Build image asus_rt-n56u-b1
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=ramips%2Fmt7621&id=asus_rt-n56u-b1
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):ramips-mt7621-$(IMAGE_RELEASE) \
	make image PROFILE=asus_rt-n56u-b1 PACKAGES="base-files ca-bundle dnsmasq dropbear firewall4 fstools kmod-crypto-hw-eip93 kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-mt7603 kmod-mt76x2 kmod-usb3 kmod-usb-ledtrig-usbport -uboot-envtools luci nand-utils -ppp -ppp-mod-pppoe -ip6tables -odhcp6c -kmod-ipv6 -kmod-ip6tables -odhcpd-ipv6only -opkg"

.PHONY: image.xiaomi_mi-router-ax3000t-ubootmod
image.xiaomi_mi-router-ax3000t-ubootmod: $(ARTIFACTS_PATH) clean.files ## Build image xiaomi_mi-router-ax3000t-ubootmod
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=mediatek%2Ffilogic&id=xiaomi_mi-router-ax3000t-ubootmod
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):mediatek-filogic-$(IMAGE_RELEASE) \
	make image PROFILE=xiaomi_mi-router-ax3000t-ubootmod PACKAGES="base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware luci \
	nand-utils \
	"

.PHONY: image.cudy_tr3000-v1
image.cudy_tr3000-v1: $(ARTIFACTS_PATH) clean.files ## Build image cudy_tr3000-v1
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=mediatek%2Ffilogic&id=cudy_tr3000-v1
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):mediatek-filogic-$(IMAGE_RELEASE) \
	make image PROFILE=cudy_tr3000-v1 PACKAGES="base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-usb3 kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware luci \
	nand-utils \
	"

.PHONY: image.glinet_gl-mt6000
image.glinet_gl-mt6000: $(ARTIFACTS_PATH) clean.files ## Build image glinet_gl-mt6000
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=mediatek%2Ffilogic&id=glinet_gl-mt6000
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):mediatek-filogic-$(IMAGE_RELEASE) \
	make image PROFILE=glinet_gl-mt6000 PACKAGES="base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls e2fsprogs f2fsck mkf2fs kmod-usb3 kmod-mt7915e kmod-mt7986-firmware mt7986-wo-firmware luci \
	nand-utils \
	"

.PHONY: image.lec-7233
image.lec-7233: $(ARTIFACTS_PATH) clean.files ## Build image lec-7233
	mkdir -p $(ARTIFACTS_PATH)/files/etc/uci-defaults
	cp lec-7233/etc/uci-defaults/* $(ARTIFACTS_PATH)/files/etc/uci-defaults/
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=x86%2F64&id=generic
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):x86-64-$(IMAGE_RELEASE) \
	make image PROFILE=generic ROOTFS_PARTSIZE=1024 FILES="files" PACKAGES="base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools grub2-bios-setup kmod-button-hotplug kmod-nft-offload libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-dwmac-intel kmod-e1000e kmod-e1000 kmod-forcedeth kmod-fs-vfat kmod-igb kmod-igc kmod-ixgbe kmod-r8169 kmod-tg3 kmod-drm-i915 luci \
	fish \
	htop \
	curl \
	wget \
	diffutils \
	tree \
	irqbalance \
	terminfo \
	ethtool \
	blkid \
	lsblk \
	usbutils \
	tmux \
	nut-upsmon \
	nut-upssched \
	luci-app-nut \
	luci-app-ttyd \
	luci-app-commands \
	luci-app-firewall \
	luci-app-opkg \
	luci-app-statistics \
	luci-mod-admin-full \
	luci-mod-network \
	luci-mod-status \
	luci-mod-system \
	collectd-mod-interface \
	collectd-mod-network \
	collectd-mod-iwinfo \
	collectd-mod-load \
	collectd-mod-memory \
	collectd-mod-cpu \
	collectd-mod-thermal \
	collectd-mod-conntrack \
	intel-microcode \
	lm-sensors \
	kmod-itco-wdt \
	smartmontools \
"

.PHONY: image.rp3-nut
image.rp3-nut: $(ARTIFACTS_PATH) clean.files ## Build image rp3-nut
	mkdir -p $(ARTIFACTS_PATH)/files/etc/uci-defaults
	cp rp3-nut/etc/uci-defaults/* $(ARTIFACTS_PATH)/files/etc/uci-defaults/
	# https://firmware-selector.openwrt.org/?version=24.10.0&target=bcm27xx%2Fbcm2710&id=rpi-3
	docker run --rm -v "$(PWD)/$(ARTIFACTS_PATH)/":/builder/bin -it $(IMAGE):bcm27xx-bcm2710-$(IMAGE_RELEASE) \
	make image PROFILE=rpi-3 ROOTFS_PARTSIZE=1024 FILES="files" PACKAGES="base-files bcm27xx-gpu-fw bcm27xx-utils ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools kmod-fs-vfat kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43430-sdio brcmfmac-nvram-43430-sdio cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-mbedtls iwinfo luci \
	fish \
	htop \
	curl \
	wget \
	diffutils \
	tree \
	irqbalance \
	terminfo \
	ethtool \
	blkid \
	lsblk \
	usbutils \
	tmux \
	nut \
	nut-server \
	nut-upscmd \
	nut-upsc \
	nut-upsmon \
	nut-upssched \
	nut-upsrw \
	nut-driver-usbhid-ups \
	luci-app-nut \
	luci-app-ttyd \
	luci-app-commands \
	luci-app-firewall \
	luci-app-opkg \
	luci-app-statistics \
	luci-mod-admin-full \
	luci-mod-network \
	luci-mod-status \
	luci-mod-system \
	collectd-mod-interface \
	collectd-mod-network \
	collectd-mod-iwinfo \
	collectd-mod-load \
	collectd-mod-memory \
	collectd-mod-cpu \
	collectd-mod-thermal \
	collectd-mod-conntrack \
	collectd-mod-nut \
"
