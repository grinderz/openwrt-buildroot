# release branch 24.10, custom branch
OWRT_VERSION_MAJOR_MINOR := 24.10
OWRT_VERSION_PATCH :=
OWRT_BRANCH := cudy-ap3000-motorcomm-24.10
OWRT_DIR := openwrt-24.10-cudy-ap3000-motorcomm
SRC_OWRT_GIT := https://github.com/grinderz/openwrt.git

# no ramips in this version; override from CLI still wins
SRC_TARGET ?= mediatek
SRC_SUBTARGET ?= filogic
