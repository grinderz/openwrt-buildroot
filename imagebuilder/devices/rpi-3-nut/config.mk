CONFIG_ROOTFS_PARTSIZE := 1024
CONFIG_TARGET := bcm27xx
CONFIG_SUBTARGET := bcm2710
CONFIG_BASE_PKGS := base-files bcm27xx-gpu-fw bcm27xx-utils ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools kmod-fs-vfat kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43430-sdio brcmfmac-nvram-43430-sdio cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-mbedtls iwinfo luci
CONFIG_CUSTOM_PKGS := \
	fish \
	luci-app-statistics \
	nut-web-cgi \
	nut-upsrw \
	nut-upssched \
	nut-upscmd \
	nut-driver-usbhid-ups \
	nut \
	nut-server \
	luci-app-nut \
	collectd-mod-nut \
	usbutils \
	tmux \
	htop \
	owut \
	blkid \
	lsblk \
	collectd-mod-thermal \
	curl \
	wget \
	diffutils \
	tree \
	irqbalance \
	terminfo \
	ethtool
