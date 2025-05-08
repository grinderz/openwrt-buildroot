CONFIG_ROOTFS_PARTSIZE := 1024
CONFIG_TARGET := x86
CONFIG_SUBTARGET := 64
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools grub2-bios-setup kmod-button-hotplug kmod-nft-offload libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-dwmac-intel kmod-e1000e kmod-e1000 kmod-forcedeth kmod-fs-vfat kmod-igb kmod-igc kmod-ixgbe kmod-r8169 kmod-tg3 kmod-drm-i915 luci
CONFIG_CUSTOM_PKGS := \
	fish \
	owut \
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
	collectd-mod-thermal \
	intel-microcode \
	lm-sensors \
	kmod-itco-wdt \
	smartmontools
