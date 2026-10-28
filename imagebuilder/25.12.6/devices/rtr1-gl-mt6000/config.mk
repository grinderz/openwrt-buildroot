CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_PROFILE := glinet_gl-mt6000
CONFIG_DEVICE := rtr1-gl-mt6000

# 25.12: ethstatus has no 25.12 build (it came from the 24.10 modemfeed);
# libstdcpp6 is the opkg name with the ABI suffix, the apk package is libstdcpp;
# the modemfeed openvpn with the netifd proto handler (luci-proto-openvpn needs
# it) is openvpn-openssl-xor in 25.12, plain openvpn-openssl is the official
# build without the handler
CONFIG_CUSTOM_PKGS := \
	beszel-agent \
	bind-dig \
	collectd-mod-sensors \
	collectd-mod-thermal \
	diffutils \
	htop \
	internet-detector-mod-telegram \
	ip-tiny \
	iperf3 \
	kmod-amneziawg \
	kmod-nft-tproxy \
	kmod-usb-ehci \
	kmod-vhost-net \
	libstdcpp \
	libudev-zero \
	luci-app-adblock \
	luci-app-attendedsysupgrade \
	luci-app-internet-detector \
	luci-app-log-viewer \
	luci-app-ssclash \
	luci-app-statistics \
	luci-app-ttyd \
	luci-app-wol \
	luci-proto-amneziawg \
	luci-proto-openvpn \
	luci-proto-wireguard \
	mtr-json \
	openconnect \
	openvpn-openssl-xor \
	owut \
	ssclash-mihomo \
	tcpdump \
	telegrambot \
	tmux \
	tree \
	usbutils \
	vim-fuller \
	\
