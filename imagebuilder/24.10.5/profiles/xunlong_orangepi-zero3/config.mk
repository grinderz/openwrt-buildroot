CONFIG_TARGET := sunxi
CONFIG_SUBTARGET := cortexa53
CONFIG_PROFILE := xunlong_orangepi-zero3
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools kmod-nft-offload libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd luci

CONFIG_CUSTOM_PKGS := \
	iperf3 \
	owut
