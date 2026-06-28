CONFIG_TARGET := ramips
CONFIG_SUBTARGET := mt7621
CONFIG_PROFILE := securifi_almond-3s
CONFIG_BASE_PKGS := apk-mbedtls base-files ca-bundle dnsmasq dropbear firewall4 fstools kmod-crypto-hw-eip93 kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls luci

CONFIG_CUSTOM_PKGS := \
	kmod-mt7603 \
  	kmod-mt7615e \
  	kmod-mt7663-firmware-ap \
  	kmod-mt76x2 \
  	kmod-usb3 \
  	-uboot-envtools \
  	kmod-usb-net-qmi-wwan \
  	kmod-usb-serial-option \
   	uqmi \
	iperf3 \
	lm-sensors \
	ethtool-full \
	kmod-phy-motorcomm \
	mdio-tools
