#CONFIG_ROOTFS_PARTSIZE := 512
CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_PROFILE := glinet_gl-mt6000
CONFIG_DEVICE := rtr1-gl-mt6000

CONFIG_CUSTOM_PKGS := \
	coreutils-base64\
	kmod-tun \
	kmod-nft-tproxy \
	kmod-thermal \
	kmod-hwmon-core \
	kmod-amneziawg \
	iperf3 \
	owut \
	htop \
	terminfo \
	curl \
	diffutils \
	tree \
	lm-sensors \
	iw \
	iwinfo \
	vim \
	mtr \
	tcpdump \
	tmux \
	irqbalance \
	bind-dig \
	usbutils \
	amneziawg-tools \
	internet-detector \
	luci \
	luci-app-ttyd \
	luci-app-watchcat \
	luci-app-irqbalance \
	luci-app-attendedsysupgrade \
	luci-app-ssclash \
	luci-app-log-viewer \
	luci-app-internet-detector \
	luci-app-interfaces-statistics \
	luci-mod-admin-full \
	luci-mod-network \
	luci-mod-status \
	luci-mod-system \
	luci-proto-amneziawg \
	-ppp \
	-ppp-mod-pppoe

CONFIG_CUSTOM_PKG_URLS := \
	\