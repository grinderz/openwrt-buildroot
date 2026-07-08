#CONFIG_ROOTFS_PARTSIZE := 512
CONFIG_TARGET := x86
CONFIG_SUBTARGET := 64
CONFIG_PROFILE := generic
CONFIG_DEVICE := generic-lec-7233
CONFIG_CUSTOM_PKGS := \
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
	luci-app-attendedsysupgrade \
	luci-app-statistics \
	luci-app-temp-status \
	luci-app-ttyd \
	curl \
	wget \
	tree \
	terminfo \
	tmux \
	smartmontools \
	blkid \
	lsblk \
	hdparm \
	usbutils \
	intel-microcode \
	iw \
	iwinfo \
	kmod-itco-wdt
