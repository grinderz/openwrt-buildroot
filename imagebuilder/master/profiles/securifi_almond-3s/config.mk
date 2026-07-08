CONFIG_TARGET := ramips
CONFIG_SUBTARGET := mt7621
CONFIG_PROFILE := securifi_almond-3s
# wifi/usb/qmi kmods come preinstalled via DEVICE_PACKAGES on the almond3s
# branch; only userspace extras here
CONFIG_CUSTOM_PKGS := \
	iperf3 \
	lm-sensors \
	ethtool-full
