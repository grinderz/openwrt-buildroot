CONFIG_TARGET := bcm47xx
CONFIG_SUBTARGET := mips74k
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear firewall4 fstools kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables nvram odhcp6c odhcpd-ipv6only opkg otrx ppp ppp-mod-pppoe procd-ujail swconfig uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-b43 kmod-usb-ohci kmod-usb2 luci
CONFIG_CUSTOM_PKGS := \
	owut \
	-ppp \
	-ppp-mod-pppoe \
	-ip6tables \
	-odhcp6c \
	-kmod-ipv6 \
	-kmod-ip6tables \
	-odhcpd-ipv6only \
	-opkg
