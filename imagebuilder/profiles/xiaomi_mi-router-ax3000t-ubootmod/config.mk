CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware luci
CONFIG_CUSTOM_PKGS := \
    nand-utils \
	owut \
	-ppp \
	-ppp-mod-pppoe \
	-ip6tables \
	-odhcp6c \
	-kmod-ipv6 \
	-kmod-ip6tables \
	-odhcpd-ipv6only
