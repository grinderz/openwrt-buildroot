# release branch 25.12
OWRT_VERSION_MAJOR_MINOR := 25.12
OWRT_VERSION_PATCH :=
OWRT_DIR := openwrt-25.12
SRC_OWRT_GIT := https://git.openwrt.org/openwrt/openwrt.git

# no ramips in this version; override from CLI still wins
SRC_TARGET ?= mediatek
SRC_SUBTARGET ?= filogic
