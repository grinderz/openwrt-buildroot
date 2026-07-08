#CONFIG_ROOTFS_PARTSIZE := 512
CONFIG_TARGET := bcm27xx
CONFIG_SUBTARGET := bcm2710
CONFIG_PROFILE := rpi-3
CONFIG_DEVICE := nut-rpi-3
CONFIG_CUSTOM_PKGS := \
	iperf3 \
	luci-app-attendedsysupgrade \
	luci-app-statistics \
	luci-app-temp-status \
	owut \
	htop \
	irqbalance \
	terminfo \
	hdparm \
	usbutils \
	tmux \
	blkid \
	lsblk \
	smartmontools \
	collectd \
	collectd-mod-cpu \
	collectd-mod-load \
	collectd-mod-memory \
	collectd-mod-thermal \
	collectd-mod-sensors \
	curl \
	wget \
	diffutils \
	tree \
	lm-sensors \
	nut-web-cgi \
	nut-upsrw \
	nut-upssched \
	nut-upscmd \
	nut-driver-usbhid-ups \
	nut-upsmon \
	nut \
	nut-server \
	luci-app-nut \
	iw \
	iwinfo \
	collectd-mod-nut
