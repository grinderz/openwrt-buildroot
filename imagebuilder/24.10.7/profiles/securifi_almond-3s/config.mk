CONFIG_TARGET := ramips
CONFIG_SUBTARGET := mt7621
CONFIG_PROFILE := securifi_almond-3s
# 2.4GHz radio drivers: the 003 patch's DEVICE_PACKAGES ships only kmod-mt76x2
# (5GHz); the author's master branch adds these to the device itself
CONFIG_CUSTOM_PKGS := \
	kmod-mt7603 \
	kmod-mt7615e \
	kmod-mt7663-firmware-ap \
	iperf3 \
	lm-sensors \
	ethtool-full
