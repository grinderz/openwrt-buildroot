CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_PROFILE := cudy_m3000-v2-yt8821
CONFIG_BASE_PKGS := apk-mbedtls base-files ca-bundle dnsmasq dropbear firewall4 fitblk fstools kmod-crypto-hw-safexcel kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware #luci

CONFIG_CUSTOM_PKGS := \
	# iperf3 \
	lm-sensors \
	ethtool-full \
	kmod-phy-motorcomm \
	mdio-tools
