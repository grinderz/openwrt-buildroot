CONFIG_TARGET := bcm47xx
CONFIG_SUBTARGET := mips74k
CONFIG_PROFILE := netgear_wnr3500l-v1-na
CONFIG_CUSTOM_PKGS := \
	-ppp \
	-ppp-mod-pppoe \
	-odhcp6c \
	-odhcpd-ipv6only

# TODO: update pkgs