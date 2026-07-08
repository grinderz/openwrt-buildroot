CONFIG_TARGET := mediatek
CONFIG_SUBTARGET := filogic
CONFIG_PROFILE := cudy_tr3000-256mb-v1
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
	luci-app-temp-status
