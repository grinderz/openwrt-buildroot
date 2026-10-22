CONFIG_TARGET := ramips
CONFIG_SUBTARGET := mt7621
CONFIG_PROFILE := securifi_almond-3s
CONFIG_DEVICE := rtr3-almond-s3

# 25.12: ethstatus has no 25.12 build (it came from the 24.10 modemfeed)
CONFIG_CUSTOM_PKGS := \
	htop \
	internet-detector-mod-telegram \
	ip-tiny \
	kmod-mt76x2 \
	kmod-mtd-rw \
	kmod-nft-tproxy \
	kmod-usb3 \
	libudev-zero \
	luci-app-3ginfo-lite \
	luci-app-adblock \
	luci-app-atinout \
	luci-app-attendedsysupgrade \
	luci-app-internet-detector \
	luci-app-modemband \
	luci-app-smstools3 \
	luci-app-ssclash \
	luci-app-statistics \
	luci-app-ttyd \
	luci-proto-mbim \
	luci-proto-qmi \
	luci-proto-wireguard \
	mbim-utils \
	mtr-json \
	owut \
	qmi-utils \
	ssclash-mihomo \
	telegrambot \
	usbutils \
	wget-ssl \
	\
