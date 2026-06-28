CONFIG_TARGET := rockchip
CONFIG_SUBTARGET := armv8
CONFIG_PROFILE := friendlyarm_nanopi-r3s
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools kmod-gpio-button-hotplug kmod-nft-offload libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd kmod-r8169 luci

CONFIG_CUSTOM_PKGS := \
	-ppp \
	-ppp-mod-pppoe \
	-odhcp6c \
	-odhcpd-ipv6only \
	owut \
	collectd \
	collectd-mod-cpu \
	collectd-mod-load \
	collectd-mod-memory \
	collectd-mod-thermal \
	collectd-mod-sensors \
	lm-sensors \
	iperf3 \
	htop \
	diffutils \
	iw \
	iwinfo \
	luci-app-attendedsysupgrad \
	luci-app-statistics \
	luci-app-temp-status \
	irqbalance \
	smartmontools \
	blkid \
	lsblk \
	hdparm \
	usbutils \
	tree \
	terminfo \
	tmux \
	curl \
	wget
