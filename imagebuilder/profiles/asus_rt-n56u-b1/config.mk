CONFIG_TARGET := ramips
CONFIG_SUBTARGET := mt7621
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear firewall4 fstools kmod-crypto-hw-eip93 kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-mt7603 kmod-mt76x2 kmod-usb3 kmod-usb-ledtrig-usbport -uboot-envtools luci
CONFIG_CUSTOM_PKGS := \
    nand-utils \
	owut \
	-ppp \
	-ppp-mod-pppoe \
	-ip6tables \
	-odhcp6c \
	-kmod-ipv6 \
	-kmod-ip6tables \
	-odhcpd-ipv6only \
	-opkg
