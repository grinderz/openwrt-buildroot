CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_PROFILE := cudy_tr3000-256mb-v1
CONFIG_BASE_PKGS := base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-usb3 kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware luci

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
	luci-app-temp-status
