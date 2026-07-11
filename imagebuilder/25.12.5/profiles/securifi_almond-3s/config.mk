CONFIG_TARGET := ramips
CONFIG_SUBTARGET := mt7621
CONFIG_PROFILE := securifi_almond-3s
# all wifi/usb/qmi kmods come preinstalled via DEVICE_PACKAGES (patch 003);
# only userspace extras here
CONFIG_CUSTOM_PKGS := \
	iperf3 \
	lm-sensors \
	ethtool-full
