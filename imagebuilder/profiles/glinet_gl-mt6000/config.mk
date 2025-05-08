CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls e2fsprogs f2fsck mkf2fs kmod-usb3 kmod-mt7915e kmod-mt7986-firmware mt7986-wo-firmware luci
CONFIG_CUSTOM_PKGS := \
    nand-utils \
	owut \
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
	luci-app-statistics \
	collectd-mod-thermal
