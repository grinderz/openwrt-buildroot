CONFIG_TARGET := rockchip
CONFIG_SUBTARGET := armv8
CONFIG_PROFILE := friendlyarm_nanopi-r3s
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
	luci-app-attendedsysupgrade \
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
